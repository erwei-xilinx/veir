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
