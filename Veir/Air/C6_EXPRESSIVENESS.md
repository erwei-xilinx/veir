# C6, phase 3: what AIR can and cannot express, relative to AIE2P DMA BDs and locks

The target model is in [`AIE_SEMANTICS.md`](AIE_SEMANTICS.md) (T1-T10). For each mechanism of the
target, this file asks four questions:
1. Does AIR's lowering (`aircc`: `air-to-aie`, `airrt-to-npu`) ever emit it?
2. What in the AIR program causes it? One of:
   - (a) an AIR op or operand with a meaning in `SEMANTICS.md`;
   - (b) an attribute;
   - (c) a heuristic or analysis in the compiler;
   - (d) a compiler option.
3. Can an AIR program state the behaviour it gives, with the semantics VeIR models?
4. If not, what is the gap?

The evidence comes from reading mlir-air at `9b81b5de0`, which was 189 commits behind main; row 13
and gap 4 are corrected for `9848a566f` (2026-11-14). File and line references are to
`mlir/lib/`. They come from a code survey (2026-11-14). Four were re-checked by hand, marked ✓:
- `out_of_order` hard-coded false;
- `iteration` passed as `nullptr`;
- `air.refeed_count` sets lock inits;
- no `WireBundle::Core` in any lowering.

## The mechanisms

| # | AIE mechanism | Emitted | Trigger | AIR meaning | C6 verdict |
| --- | --- | --- | --- | --- | --- |
| 1 | Lock init > 1, acquire/release values > 1 (counting, n-buffering) | yes, `allocateLockOp` (`Conversion/AIRToAIESchedulingUtils.cpp:128`) | (c) the number of buffers a channel rotates through (`getLockValuePair`, :472-512, :710-751); (b) `air.refeed_count = N`, which the pass `air-annotate-refeed` derives from an N-trip loop around one put | ping-pong, or re-sending one buffer N times. Both are a loop in AIR, with defined meaning | **Behaviour expressible, depth not.** The number of buffers (n-buffering beyond 2) cannot be chosen in AIR: `depth` is documented but not implemented (AIR-010). It comes from the ping-pong heuristic or from rotation detection |
| 2 | BD `iteration` (address advances per run) | **no** (`Conversion/AIRRtToNpuPass.cpp:1102`, `nullptr` ✓) | — | the same address walk can be written as a loop of channel ops with an offset on the induction variable; it lowers to more BDs or dimensions instead | **Mechanism never used; behaviour expressible.** The target is used less efficiently, not less expressively |
| 3 | `repeat_count` on `aie.dma_start` and on runtime tasks | yes (`AIRToAIEPass.cpp:7182`; `AIRRtToNpuPass.cpp:1044-1051`) | (c) the trip count of the loops around a channel op (`getRepeatCounts`, SchedulingUtils:318-449); (a) a stride-0 outer dimension on an L3 transfer | a loop, or a stride-0 dimension ("repeat", as for DMAs) | **Expressible.** T5 says each repeat re-acquires its locks; whether the lowering's lock values match the repeat is a phase-2 question (see the disputed memory note on refeed garbage) |
| 4 | BD padding | yes (`AIRToAIEPass.cpp:7350-7380, 7496-7505`) | (b) `pad_before`/`pad_after` on `air.channel.put/get`, usually added by `air-split-launch-for-padding`; `pad_value` is always 0 | D20/D31: zeros in the padded positions | **Expressible** (zero padding only; a non-zero pad value cannot be stated) |
| 5 | Out-of-order S2MM (packets placed by an id in their header) | **no** (`AIRToAIEPass.cpp:7184`, `false` ✓) | — | none | **Gap.** No AIR construct lets a receiver take packets out of order into the BD their header names |
| 6 | `keep_pkt_header` | yes (`AIRToAIEPass.cpp:4630-4636`) | (b) a channel attribute; (c) added to forwarding hops by `air-annotate-packet-ids` | a forwarding stage keeps the routing decision | expressible; not modelled yet (T7) |
| 7 | Packet flows, packet ids, dynamic `dest` | yes (`AIRToAIEPass.cpp:4630-4714`) | (b) `channel_type = "npu_dma_packet"`, `packet_ids`; (a) the `dest` operand of `air.channel.put` | D29: a put's data goes to the destination it selects | **Expressible.** Phase 2: 20 of 24 packet relays correct, the other 4 are AIR-022 |
| 8 | Cascade (core to core) | yes (`AIRToAIEPass.cpp:4807-4830, 7524-7530`) | (b) `channel_type = "npu_cascade"` | D32: a channel like any other | expressible; not modelled (refused) |
| 9 | Shared L1 between neighbouring tiles, with a lock handshake | yes (`allocateSharedL1BufferLocks`, `AIRToAIEPass.cpp:1255`) | (c) an L1 alloc used by more than one herd, or by one herd with `herdBufferHasCrossCoreDependence` | **none that is race-free.** Under D46 = A it is one buffer; tiles of one herd, or herds running at the same time, have no tokens between them (D37), so concurrent hand-off through it is a race in AIR | **Gap (the main one).** AIR cannot express synchronised producer/consumer communication through shared memory between concurrently running tiles. Designs that use it (e.g. neighbour-memory convolution) are racy IR that the lowering turns into locks by inference (AIR-016, AIR-023) |
| 10 | Multi-BD chains, ping-pong | yes (`generateDmaBdProgram`, `AIRToAIEPass.cpp:6851`) | (c) `air-label-scf-for-to-ping-pong`; (b) `unroll`, `hoist_alloc`; (d) `omit-ping-pong-transform`, `use-lock-race-condition-fix` | the same loop; double buffering is not part of AIR's meaning | **Expressible** (the behaviour is the loop's). Correctness of the lowering is phase 2's subject: AIR-022 is here |
| 11 | Flows ending at a core (`WireBundle::Core`), cores reading or writing streams | **no** (no `WireBundle::Core` in `Conversion/` ✓; only cascade) | — | none | **Gap.** A core cannot consume or produce a stream word by word; every stream end is a DMA (or a cascade) |
| 12 | Runtime-parameterised BDs (offset, length, repeat chosen at run time) | yes (`AIRRtToNpuPass.cpp:848-900, 1039-1051, 1088-1103`) | (a) non-constant offsets or sizes on L3-side transfers (one runtime dimension) | launch-level values (VeIR requires them known: `--args`) | expressible, with one runtime dimension |
| 13 | Runtime register writes: `aiex.set_lock`, `npu.write32`, control packets | yes, since #2261 (`7b20edb5f`, 2026-11-04): a core (or the host) patches a BD's offset (or length) and starts it through control packets (`lowerDeviceIssue`, `lowerOnChipIssue` in `AIRToAIEPass.cpp`; host tables in `AIRRtToNpuPass.cpp`). Also `set_lock` on a herd lock; `write32` for tracing | (a) `air.channel.issue` paired with a channel op tagged `air.device_issue`, produced by `air-dma-to-channel` from a put/get whose offset a core computes or whose length is a run-time scalar | a transfer whose offset or length is known only at run time | **Expressible** (since #2261). Its semantics is not yet confirmed or modelled in VeIR |

## The gaps

1. **Synchronised shared memory between concurrent tiles** (row 9). The hardware has lock-protected
   hand-off through a neighbour's L1. AIR has no construct for it:
   - tokens order events within one instance, not across tiles running at the same time (D37);
   - a hierarchy op's token only fires at its end (D38).

   What designs write instead is racy under D46 = A. The compiler recovers the intent by inference,
   and that inference is unsound per element (AIR-016) and a hack per D47 (AIR-023).
2. **Choosing the buffering depth** (row 1). Locks count arbitrarily; AIR cannot say "triple
   buffer this". `depth` is documented but not implemented (AIR-010).
3. **Out-of-order reception** (row 5) and **core stream ends** (row 11) are hardware modes no AIR
   construct reaches.
4. ~~Run-time reconfiguration~~: withdrawn. The earlier survey read a checkout 189 commits behind main;
   `air.channel.issue` (#2261) lets a core or the host patch and start a transfer through control
   packets (row 13).

Gaps of mechanism only, where AIR reaches the same behaviour by other means: BD iteration (row
2), non-zero pad values (row 4).

## Next

- Confirm the framing of gap 1 with the user (it is the biggest claim here).
- Confirm the semantics of `air.channel.issue` with the user, then model it.
- Model cascade and `keep_pkt_header` so that rows 6 and 8 can be validated as rows 3, 7 and 10
  were.
