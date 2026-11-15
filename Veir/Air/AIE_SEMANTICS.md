# Target model for C6: AIE2P DMA buffer descriptors and locks

C6 asks what AIR cannot express relative to a target model. The target chosen (2026-11-14) is
the AIE2P (NPU2) DMA and lock machinery, at the level `air-to-aie` and `airrt-to-npu` produce:
`aie.device` before `aiecc`. Each decision below says what the model assumes about the hardware
and who confirmed it. As in `SEMANTICS.md`, nothing is encoded before it is confirmed.

| # | Decision | Status |
| --- | --- | --- |
| T1 | A lock is a counting semaphore with an initial value (`init`). `AcquireGreaterEqual v` waits until the value is ≥ v, then subtracts v. `Release v` adds v. No upper bound is modelled. No other acquire mode exists on AIE2P | ✅ 2026-11-14 ("暂时assume无上限"; "无" other modes) |
| T2 | `aie.dma_start(dir, ch, ^bd, ^next)` starts channel `ch` on the BD chain at `^bd`. Each BD, in order: its acquire, the transfer of its access pattern, its release, then `aie.next_bd`. `aie.end` stops the chain; a cycle of `next_bd` runs forever | ✅ 2026-11-14 |
| T3 | Streams have **no buffering**: a word moves only when its sender and its receiver both take part (a rendezvous), as AIR's async transfers do (D30). FIFO depths are a hardware detail the compiler cannot control | ✅ 2026-11-14 ("assume没有buffer深度") |
| T4 | A core runs its body in program order: locks as T1, other computation as opaque reads and writes. Cores are persistent: a core stops at `aie.end` and is not restarted. A core may loop forever with a `cf.br` back to the start of a block ("while true"), which must be modelled | ✅ 2026-11-14 |
| T5 | `repeat_count = N` (on `aie.dma_start`, a task, or a queue push) runs the whole task — the BD chain from its first BD to `aie.end` — N + 1 times. Each run performs every BD's acquire and release again. An endless chain never completes, so its repeat count is meaningless | ❓ researched in mlir-aie `35fa6b1`, to be confirmed (see below) |
| T6 | A sending BD with `packet = <pkt_type, pkt_id>` emits one packet per run: a header and the BD's data. The packet ends with the BD (TLAST) | ✅ 2026-11-14 (section-2g: "stamps a packet header on every transfer this BD emits") |
| T7 | A DMA destination (or a shim's South port) drops the header; with `keep_pkt_header`, the header is one extra word (not modelled yet: refused) | ✅ 2026-11-14 (routing.md) |
| T8 | Packets do not interleave: a receiver taking a packet takes all of it before another. Packets from different senders arrive in any order. A packet flow with several destinations delivers each packet to all of them at once | ✅ 2026-11-14 (routing.md: "An arbiter holds its grant until the packet it is passing ends") |
| T9 | A (not out-of-order) S2MM BD ends when it has received its length; packet boundaries do not end it, and a packet ending mid-BD lets the BD continue with the next packet. Out-of-order S2MM is refused | ✅ 2026-11-14 |
| T10 | The model works at `aie.packet_flow` level, before switchbox routing: each flow is its own path, competing only at shared destination ports. Arbiter sharing is the router's concern (routing.md: it avoids the deadlocks it could cause). `pkt_type` plays no part in routing | ✅ 2026-11-14 |

## T5, the evidence

- `aie.dma_start` ODS (`include/aie/Dialect/AIE/IR/AIEOps.td:1464`): "repeat_count==0 means 'do it
  once' and don't repeat".
- `programming_guide/section-2/section-2g/README.md`: a queue-push `repeat_count` only means
  something for a chain that ends in `aie.end`: "an endless chain never completes, so there is
  nothing to repeat".
- `programming_guide/section-2/section-2d/DMATasks.md`: a `[2, 3, 4, 8, 16]` transfer runs a
  `[4, 8, 16]` BD 6 times, with the task's repeat count set to match.
- ObjectFifo lowering balances a repeated DMA as follows:
  - the DMA acquires 1 per run, with `dma_start ... repeat_count = repeat - 1`
    (`AIEObjectFifoLowerDMAs.cpp:140, 212-228`);
  - the core releases `relNumber * repeat` (`AIEObjectFifoLowerCores.cpp:173`).

  This balances only if every repetition re-acquires the lock.

ObjectFifo's per-BD repeat (`ping, ping, pong, pong`) is made by copying BDs when the hardware
repeat cannot express it (`copies = repeat`, `AIEObjectFifoLowerDMAs.cpp:218`). It is not a
separate hardware mode.

## The model (`Veir/Air/Aie.lean`, `air-veir aie`)

**Supported:**
- `aie.tile`, `aie.lock` (with `init`), `aie.buffer`, `aie.external_buffer`;
- BD chains in `aie.mem`, `aie.memtile_dma` and `aie.shim_dma`: acquires, one `aie.dma_bd` (offset,
  length, sizes/strides outermost first), releases, `aie.next_bd` or `aie.end`, and
  `repeat_count` (T5);
- DMA-to-DMA `aie.flow`s, a sender reaching several receivers as a broadcast (T3: all take each
  word);
- `aie.packet_flow`s between DMAs, with BD and shim-task packet ids (T6-T10);
- cores as code: `aie.use_lock`, `cf.br`, `scf.for` with constant bounds, `aie.end`. Each run of
  lock-free ops between them is one atomic `exec`, interpreted: `arith`, `memref.load`/`store`
  (indices may be constants, inner induction variables, or those of enclosing counter loops),
  `memref.copy`, and lock-free `scf.for`. Any other op is an opaque computation on its memref
  operands (D22). A value computed before a lock operation and used after it is refused. An
  error at run time (out of bounds, an arith failure) is reported as a FAULT;
- runtime sequences of `aiex.dma_configure_task_for` (on an `aie.shim_dma_allocation`),
  `aiex.dma_start_task`, `aiex.dma_await_task` and `aiex.dma_free_task`.

Host arguments start as AIR's model starts them (`1000·j + q`), so outcomes compare across the two
models.

**Partial-order reduction** is on by default (`--no-por` turns it off). It uses stubborn sets over
agents (each channel, each core, the runtime):
- an enabled action pulls in every agent that could ever conflict with it, judged on the agent's
  whole static footprint: competing acquires, buffer read/write overlap, transfer parties,
  anything touching host memory or shim channels;
- a disabled action pulls in the agents that could enable it.

Only the closed set's steps are expanded. Terminal states (deadlocks, the end of the runtime
sequence) are preserved by Valmari's argument, which is not formalised here. The tests and
`check_lowering.py --compare-por` compare the two.

**Exploration:** every interleaving, with these normalisations:
- local moves are taken eagerly: entering a BD's transfer or releases, advancing the chain, core
  control flow;
- a transfer moves as many elements as all parties have left in their BDs.

An **outcome** is host memory when the runtime sequence ends. A **deadlock** is a reachable state
where the sequence has not ended and nothing can move; it is reported with the steps reaching it.
More than one outcome means the design is nondeterministic.

**Refused for now, with the op named:**
- `keep_pkt_header`, out-of-order S2MM; core or cascade stream ends;
- BD padding and `iteration`;
- runtime offsets and lengths;
- `cf.cond_br` / `scf.if` in cores;
- `npu.write32` and other runtime ops.

**Not modelled:**
- timing;
- interleavings finer than an `exec` (it runs atomically, as an AIR event does).

**Trusted, not proven:** the extraction, the semantics and the explorer. They are executable code,
tested by `Test/Air/aie.mlir`.

## Findings so far

- **AIR-022:** `air-to-aie` lowers an in-place relay (get into a buffer, then put it, in a loop) to
  ping-pong BDs whose S2MM can refill a buffer before the MM2S has sent it. The lowered design has
  4 outcomes; the AIR input has 1.
- Phase 2 (`Test/Air/bounded/check_lowering.py`, 24 in-place relay programs):
  - 14 lowered correctly;
  - 6 are AIR-022: every K = 4 case within the bound, and only those;
  - 4 exceeded 2M states (a 2×1 herd through L2). With partial-order reduction, 2 of them
    complete (both correct), and 2 still exceed 2M (K = 4).
  - `--compare-por`: wherever the unreduced search completes, the reduced one gives the same
    deadlock verdict and the same set of outcomes (all 16 for the 2×1 K = 4 designs).

  The memtile relay is lowered correctly; the L1 relay with a core between its S2MM and MM2S
  is not.
- Phase 2, extended: 60 programs (in-place or copy relays; direct, L2, or broadcast to two
  tiles). Results:
  - 50 correct, including all 30 copy relays;
  - 8 are AIR-022: every in-place K = 4 case that completes;
  - 2 exceed 2M states;
  - 0 mismatches with and without partial-order reduction.
