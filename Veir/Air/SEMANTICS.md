# AIR semantic decisions

Every choice about what an AIR construct *means* is recorded here, with its status. A theorem is
only as good as the model it is about, and the model is only as good as these decisions. They are
made by the AIR developers, not inferred from the code alone.

Status: ✅ confirmed by an AIR developer · ❓ pending confirmation · ❌ rejected (the old reading
is wrong; the replacement is pending or recorded).

| # | Decision | Status | Where encoded | Theorems that depend on it |
| --- | --- | --- | --- | --- |
| D1 | Blocking `air.wait_all` | ✅ 2026-11-13 | `EventKind.waitAllBlocking`, `Event.implicitDeps` | `steps_between_iff` (applied to the AIR rewrite) |
| D2 | `air.wait_all async` does not block | ✅ 2026-11-13 | `EventKind.waitAll` | — |
| D3 | Unordered async ops may run in any order and overlap | ✅ 2026-11-13 | `Ready`, `Step` | all trace theorems |
| D4 | A value is ordered by a token path, direct or transitive; with no path, the program is wrong | ✅ 2026-11-13 | `Program.finishEvent` (fault), `Program.unorderedReads` | `Program.steps_reduce_iff` |
| D5 | `func.return` does not wait for outstanding events | ✅ 2026-11-13 | `func.return` is not an event | none yet |
| D6 | Conflicting memory accesses (RAW, WAR, WAW) must be ordered by tokens | ✅ 2026-11-13 | not encoded (memory not modelled) | none yet |
| D7 | Effects of an `air.execute` take place at its finish | ❓ awaits the proof described below; no question for the AIR developers | `Sem`, `Program.sem` | `Program.steps_reduce_iff` |
| D8 | Terminator/result mismatch is an AIR verifier bug | ✅ 2026-11-13 | `executeBody` refuses it | — |
| D9 | `!air.token` and affinity/concurrency lists are planned | ✅ 2026-11-13 | not encoded | — |
| D10 | `air-dependency-canonicalize` is an exact transitive reduction | ✅ 2026-11-13 | `DepGraph.reduce` | `reach_reduce_iff`, `steps_reduce_iff` |
| D11 | Function-level `arith.constant` runs before any event | not a semantic choice | `Program.initState` | — |
| D12 | An op's async dependencies are waited for before it starts, DMAs included | ✅ 2026-11-13 | `Ready` | all trace theorems |
| D13 | A DMA is an async op with read and write footprints; correctness is that conflicting accesses are ordered by tokens | ✅ 2026-11-13 (my time-window model ❌) | layer 2, not yet encoded | — |
| D14 | Access-pattern addressing: element `k` at `Σ (offsets[i] + k[i]) · strides[i]` (the code's convention, not `memref.subview`'s) | ✅ for now, 2026-11-13; long-term alignment with subview open | layer 2 | — |
| D15 | DMA src and dst have their own patterns; stride 0 repeats; `N(dst) = N(src) + padding` | ✅ 2026-11-13 | layer 2 | — |
| D16 | Memory spaces 0 = L3, 1 = L2, 2 = L1; disjoint address spaces at function scope | ✅ 2026-11-13 | layer 2 | — |
| D17 | `memref.dealloc` ends a lifetime; deallocating a buffer with an unordered access is an error | ✅ 2026-11-13 | layer 2 | — |
| D19 | Distinct top-level memref arguments are distinct storage | ✅ 2026-11-13; **differs from upstream** (`UPSTREAM_DIVERGENCES.md`) | layer 2 | — |
| D20 | A DMA is a stream: src read in traversal order, zero padding inserted on the src side, nested per dimension; dst written in traversal order. `N(dst) = Π (size_i + pad_before_i + pad_after_i)` | ✅ 2026-11-13 | layer 2 | — |
| D21 | Within one DMA, a location read at stream step i and written at step j is well defined iff i ≤ j, otherwise an intra-DMA race; repeated writes to one location (dst stride 0): the last wins | ✅ 2026-11-13 | layer 2 | — |
| D22 | Footprint of an op the model does not interpret: read and write of every memref operand's whole buffer (linalg: `ins` read, `outs` read and write); its values are opaque | ✅ 2026-11-13 | layer 2 | — |
| D23 | Non-constant offsets, sizes and strides: evaluated when running; a footprint that is not known statically is the whole buffer | ✅ 2026-11-13 | layer 2 | — |
| D24 | `air.dma_memcpy_nd` without `async` is synchronous: it runs in program order, and the host waits for it | ✅ 2026-11-13 | `EventKind.dmaBlocking`, `Event.implicitDeps` | `steps_between_iff` (implicit edges) |
| D25 | A synchronous op waits only for its own dependencies, not for earlier async ops it does not name | ✅ 2026-11-13 | `extractMem` | — |
| D26 | `scf.for` iterations are issued in program order; only the tokens `iter_args` carry order iteration N+1 after N | from `docs/AIRComputeModel.md` ("an op that does not depend on `%t_prev` may begin before iteration N's `scf.yield` fires"); consistent with D3, D25 | `Veir.Air.Instance.forLoop` | — |
| D27 | `scf.parallel` iterations are all concurrent; the result is the reduction of their values (`air.wait_all` joins) | from `docs/AIRComputeModel.md` ("all instances concurrent, tokens reduced") | `Veir.Air.Instance.parallelLoop` | — |
| D28 | A channel's `size` is a bundle of independent subchannels (any rank); each subchannel (one index) is its own FIFO | ✅ 2026-11-13 | layer 4 | — |
| D29 | A channel is a spatial hardware stream between tiles. Without `broadcast_shape` it is one-to-one; with it, every put is consumed by N gets at different tiles, simultaneously. With `dest`, a packet flow routes each put to one destination chosen at run time | ✅ 2026-11-13 | layer 4 | — |
| D30 | A transfer is buffered (unbounded) if either of its ends is sync, and a rendezvous (no buffer, so backpressure deadlock is possible) if both are async | ✅ 2026-11-13 | layer 4 | — |
| D31 | Padding: a put inserts zeros into the stream (as D20); a get writes zeros to the padded positions of its destination and takes the rest from the stream | ✅ 2026-11-13 | layer 4 | — |
| D32 | All channel types (`npu_dma_stream`, `npu_dma_packet`, `npu_cascade`, `npu_mmio`, `gpu_*`) have this semantics | ✅ 2026-11-13 | layer 4 | — |
| D33 | Two endpoints on the same subchannel, in the same direction, with no token path between them, are an error (a channel FIFO-order race) | ✅ 2026-11-13 | layer 4 | — |
| D34 | A subchannel is a stream of elements: puts and gets need not pair one to one; the i-th element put is the i-th element got. Elements no get takes leave an async put stuck (backpressure) | ✅ 2026-11-13 | layer 4 | — |
| D35 | A sync `channel.put`/`channel.get` is a blocking event (as D24) | ✅ 2026-11-13 | layer 4 | — |
| D36 | What a transfer orders, for memory: (a) within the transfer, a location read at stream step i and written at step j is defined iff i ≤ j; (b) a get's completion orders everything after it after the feeding put's reads of the elements it received | (a) ✅ 2026-11-13 (AIR-011); (b) ✅ 2026-11-13 ("这是dependency canonicalization的transitive reduction能成立的原因") | `Veir.Air.Channels.raceEdges` | — |
| D37 | Instances: `herd` tiles and `segment` instances all run concurrently; `launch` instances may run in parallel or in any sequential order, so instances of one launch must not communicate (a channel between two of them is an error) | ✅ 2026-11-14 | layer 5 | — |
| D38 | When a hierarchy op's token fires: after every event inside it, in every instance, has finished, including events nothing inside awaits (unlike `func.return`, D5). Conflicts with `channel_drain_hierarchy.mlir` under D30 | ✅ 2026-11-14 (reading (i), "我倾向这个"; reconfirmed "坚持(i)" after seeing that NPU erases segment tokens); `channel_drain_hierarchy.mlir`'s output then deadlocks | layer 5 | — |
| D39 | A hierarchy op's dependencies gate the start of every instance; without a result it is blocking (as D24); a sync op inside an instance blocks only that instance | ✅ 2026-11-14 | layer 5 | — |
| D40 | `memref.alloc` inside a body is private to each instance (each herd tile has its own L1 buffer); kernel operands are passed by reference (the same buffer as outside) | ✅ 2026-11-14 | layer 5 | — |
| D41 | A hierarchy op's memory footprint, for races, is the union of the events inside it (precise), not every buffer in its `args` (what `air-dependency` assumes) | ✅ 2026-11-14 | layer 5 | — |
| D42 | A token passed into a body through `args` is the outer event; inner events listing it wait for it | ✅ 2026-11-14 | layer 5 | — |
| D43 | `air.rank` follows the same rules as `segment`/`herd` (D37-D42): its instances (ranks, e.g. GPUs) run concurrently | ✅ 2026-11-14 ("和herd/segment的hierarchy的规矩应该一样的") | layer 5 | — |
| D44 | `affinity`/`concurrency` token lists are refused: not implemented in AIR (D9) | ✅ 2026-11-14 | layer 5 | — |
| D45 | An op without `async` that is not otherwise an event (`memref.dealloc`, `linalg.*`, `func.call`, `memref.copy`, ... at host level or in a hierarchy body) is a blocking event, in program order, as D24/D35 ("可以，当作阻塞事件") | ✅ 2026-11-14 | layer 5 | — |
| D46 | An L1 alloc outside a herd, used by one herd, is **one shared buffer** (reading A; D40 unchanged): `AIRToAIE`'s per-core clone is an implementation, equivalent only when tiles' accesses are disjoint. `air.shrinkage` has no meaning of its own | ✅ 2026-11-14 ("A") | layer 5 | AIR-015 |
| D47 | An L1 buffer outside a herd that every tile reads and writes whole (scratch), or passes whole to a kernel every tile calls, is **invalid IR**: under D46 = A the tiles race on one buffer. The frontend should allocate it inside the herd. AIR's per-core privatisation of such buffers (`herdBufferHasCrossCoreDependence`'s rules, the LOCAL clone path, the verifier's "pass 1") is a hack to be fixed (AIR-023) | ✅ 2026-11-14 ("(a)"; "这个应该是hack…我们最终应该把它修了") | races reported (`hierarchy.mlir`, `@herd_scratch`) | AIR-016, AIR-017, AIR-023 |
| D48 | `air-to-aie` test inputs that put a sync `channel.get` in a segment before the herd feeding it are lowering fixtures, not valid programs; D35 stands (they deadlock under it) | ✅ 2026-11-14 ("a，那些只是lowering的测试写法") | sweep verdicts `async bad` | — |
| D49 | (1) `air.custom` is an event (async with a result, blocking without), reading and writing each memref operand whole, opaque values. (2) `memref.alloc {air.symmetric}` belongs in an `air.rank` body: one buffer per rank, a family. (3) A cross-rank DMA side (`src_rank`/`dst_rank` = R) addresses rank R's buffer of the family; ranks are ordered only through channels. (4) `air.translate %src, %from, %to` is rank `%to`'s buffer of `%src`'s family, `%src` must be rank `%from`'s; heap bases play no part | ✅ 2026-11-14 ("1 2 3 4 都对") | `Instance.lean`: `symmetricBuffer`, `peerBuffer`, `translateInstance`, `customInstance` | AIR-021 |
| D50 | On a channel whose every dimension has size 1 (e.g. `[1, 1]`), an endpoint with no indices (`@C[]`) names subchannel `[0, ..., 0]`, as `aircc` connects them | ✅ 2026-11-14 ("D50 对") | `channelInstance` | — |
| D22a | Refinement of D22 (2026-11-14): `memref.copy` between whole buffers (no view, no strided layout, equal sizes) copies element by element, as upstream MLIR defines it. Its footprint is unchanged (reads the source, writes the destination); other uninterpreted ops stay opaque | upstream semantics; no AIR decision involved | `finishExecute` | — |

## D1. Blocking `air.wait_all` ✅

`air.wait_all` without `async` (and so without a result) blocks the host until its dependencies are
done. Nothing after it is issued before that, so every later event waits for it although no operand
says so.

```mlir
air.wait_all [%a]
%b = air.execute { ... }   // waits for %a, through the blocking wait
```

## D2. `air.wait_all async` ✅

`air.wait_all async [...]` does not block. It is an event that completes once its dependencies are
done.

## D3. Unordered async ops ✅

Two async ops with no token path between them may run in either order and may overlap. Having
its dependencies met allows an op to start; it does not force it to.

## D4. Using a value requires a token path ✅

A use of an `air.execute` result need not name that execute's token directly. The canonicalizer
removes the direct edge when an intermediate op already orders the two:

```mlir
%t, %v = air.execute -> (i32) { ... }
%m = air.execute [%t] { use %v }     // depends on %t
%u = air.execute [%m] { use %v }     // uses %v; ordered after %t through %m
```

There must be a token path, direct or transitive, from the producer to every user. A program
without one is wrong: the `air-dependency` pass should have created the path. The model reports
that program as a data race: `air-veir graph` warns, and any schedule that runs the user first
faults. Since the reduction preserves reachability (`reach_reduce_iff`), it can never create such
a race.

## D5. `func.return` does not wait ✅

A function may return while events it issued are still outstanding. Returning a token hands the
wait to the caller:

```mlir
func.func @wait() -> !air.async.token {
  %e = air.wait_all async [...]
  return %e : !air.async.token    // does not wait for %e
}
```

`func.return` is not an event, and a complete trace runs every event to completion. Once calls
are modelled, the caller will see the returned token as a dependency it may wait for.

(History: this reading was first questioned, then confirmed the same day.)

## D6. Memory conflicts must be ordered ✅

When several `air.execute`s (and later DMAs) access the same memory, the `air-dependency` pass is
responsible for adding token edges, direct or transitive, that order every RAW, WAR and WAW pair
of accesses. Reads after reads need no ordering. This matches
`mlir/lib/Transform/AIRDependency.cpp`, which detects RAW and WAW/WAR (lines 255–291). A conflict
left unordered is a program error.

**Confirmed 2026-11-13:** every RAW, WAR and WAW between accesses to the same memory addresses
must be registered as a dependency, and catching all of them is `air-dependency`'s job. "Same
addresses" means the footprints overlap. `air-dependency` currently compares start addresses
instead, which misses overlapping accesses of different shapes; tracked as AIR-007 in
`~/air-issues`.

**Consequence for the model, once memory is added.** An unordered conflict will be a race,
reported as a fault, not given a meaning. For race-free programs, non-conflicting bodies commute,
so how event bodies interleave cannot change the result. That is what makes D7 safe.

## D7. Effects of an `air.execute` take place at its finish ❓ (awaits a proof)

The model applies a body's effects atomically when the event finishes. For pure `arith` bodies
this is unobservable. With memory, D6 makes it sound: in a race-free program, two bodies that may
run at the same time access no memory in conflict, so any interleaving of their steps has the
same effect as running one and then the other. This needs no further input from the AIR
developers. It becomes ✅ when the memory model is added and that commutation argument is proven:
fine-grained interleavings of race-free programs equal atomic ones.

## D8. Terminator/result mismatch is a bug ✅

`air.execute -> (index)` whose terminator yields an `i32`, or yields nothing, is accepted by
`ExecuteOp::verify`. That is a verifier bug. VeIR's structure check mirrors AIR's for now, and
`extract` refuses the op.

## D9. `!air.token` and affinity/concurrency lists are planned ✅

`docs/AIRComputeModel.md`'s `!air.token`, `air.token.alloc` and the three token lists
(`dependency`, `affinity`, `concurrency`) are planned. The model must leave room for them:
- **`dependency`** is the ordering modelled now (`Reach`).
- **`affinity`** is a constraint on resources. It implies disjoint lifetimes, so at least
  "not overlapping".
- **`concurrency`** requires overlapping lifetimes. That is a *liveness* requirement, which the
  current model can state (`start`/`finish` labels give lifetimes) but does not yet constrain.
  Note that it can deadlock with dependencies, and with resources.

## D10. `air-dependency-canonicalize` is an exact transitive reduction ✅

The pass computes the minimal dependency graph: it removes exactly the edges implied by other
paths, and no others. An output that also dropped an edge not implied by another path would be a
bug, and `air-veir check` rejects it.

## D11. Function-level constants

`arith.constant` in the function body is evaluated before any event. It is pure, so when it runs
cannot be observed. This is a modelling convenience, not a semantic decision.

## D12. Dependencies are waited for before an op starts ✅

`air.dma_memcpy_nd async [%t]` starts reading and writing only after `%t` completes, like every
other async op (D3, `Ready`). The lowering (`air-to-std`) may implement this differently, by
folding a channel op's dependencies into its completion event, but that is the lowering's
business: the AIR semantics is start-after.

## D13. A DMA is just another async op that touches memory ✅

There is no special DMA timing model. A DMA, like an `air.execute`, is an async op with a read
footprint (src) and a write footprint (dst). The program is correct when every pair of ops whose
footprints share an address, with at least one write (RAW, WAR, WAW; D6), is ordered by a token
path. The `air-dependency` pass is what creates those edges.

**Rejected:** my proposal to model when, inside [start, finish], a DMA touches memory, and to
forbid unordered accesses during that window. Under D6 an unordered conflicting pair is an error
whatever the timing, so the window adds nothing.

Consequence: once a program is race-free, applying each op's effect atomically at its finish
(D7) cannot be told apart from any interleaving. Layer 2 proves that.

## D14. How an access pattern addresses memory ✅ (for now)

The answer was: "完全按照 upstream mlir memref subview 的格式". The code uses a different
convention, consistently:
- `getLinearAccessRange` (`Util.h`): "the offset counts in units of that dimension's stride";
- `AIRToAIESchedulingUtils.cpp:194`: `one_d_offset += offset * stride_i`;
- `AIRRtToNpuPass.cpp:935`: `offset = sum(offsets[i] * strides[i])`.

That is, element `k` of the pattern is at linear position `Σ (offsets[i] + k[i]) · strides[i]`
of the underlying buffer, where `strides` are linear element strides, and the number of
dimensions need not equal the memref's rank. `memref.subview` instead puts element `k` at source
coordinates `offsets[i] + k[i] · strides[i]`, linearised by the source's layout, with one entry per
dimension of the source. The two agree when the subview strides are 1 and AIR's strides are the
layout strides; they differ otherwise. Pending: which one is AIR's semantics?

**Measured 2026-11-13.**
- `memref.subview %m[4] [4] [2]` on `memref<16xi32>` has layout `strided<[2], offset: 4>`
  (elements 4, 6, 8, 10). MLIR's verifier rejects `offset: 8`.
- AIR's `airrt-to-npu` lowers offsets `[4]`, sizes `[4]`, strides `[2]` to
  `aie.dma_bd(... offset = 8 ...)` (elements 8, 10, 12, 14).
- mlir-aie (`35fa6b1`, the pinned version) does the same as AIR in its implementation:
  `NpuDmaMemcpyNdOp::getOffsetInBytes` computes `Σ offsets[i]·strides[i]`, and `aie-opt
  --aie-dma-to-npu` patches 32 bytes for the 1-D example and 72 for the 2-D one.
- mlir-aie's **documentation** of that op describes the shape-relative, subview-like reading (16
  and 40 bytes). The doc contradicts the implementation: AIE-001 in `~/air-issues`.

So the whole toolchain implements "offset in units of the dimension's stride". Only the
mlir-aie doc and the `memref.subview` analogy say otherwise.

**Decided 2026-11-13: follow the code's convention for now.** Whether AIR should move to
`memref.subview`'s convention in the long term is open.

AIR's own subview folding (`air-copy-to-dma`, the DMA canonicalizer) copies a subview's offsets
unchanged, as if the convention were subview's. With a non-unit step, the lowering then moves the
wrong elements: AIR-009.

## D15. DMA patterns ✅

- src and dst each have their own offsets, sizes and strides.
- A stride of 0 repeats that dimension (the same elements are read again).
- src and dst must describe the same number of elements, except that padding adds to dst:
  `N(dst) = N(src) + padding` (confirmed). Otherwise one side would back-pressure.
  `DmaMemcpyNdOp::verify` does not check this: AIR-008.
- Empty lists mean the whole memref.
- Strides count elements.

## D16. Memory spaces ✅

Memory space 0 (the default) is L3, 1 is L2, 2 is L1. At function scope (layer 2) they are
treated as disjoint address spaces, and which unit may access which level is left to the
`herd` layer.

## D17. `memref.dealloc` ✅

`memref.dealloc` ends a buffer's lifetime and conflicts with every access to the buffer. A dealloc
not ordered after every access, or an access ordered after the dealloc, is an error
(use-after-free).

This raised a suspicion: the ping-pong transformation may use a dealloc to mark the end of a
buffer's lifetime in a way that breaks this rule. Tracked as AIR-006 in `~/air-issues`; not yet
investigated.

## D19. Top-level memref arguments do not alias ✅ (differs from upstream)

`func.func @f(%a: memref<16xi32>, %b: memref<16xi32>)`: `%a` and `%b` address distinct storage.
This is the assumption AIR's own code already makes (`AIRDialect.cpp:263–267`: "the AIR-domain
assumption that distinct top-level memref SSA values address distinct storage").

Upstream MLIR assumes the opposite. `LocalAliasAnalysis` returns `MayAlias` for two values with
no allocation effect. Upstream's way to state non-aliasing is `memref.distinct_objects`, under
which aliasing is undefined behaviour. Recorded for later review in
`~/air-issues/UPSTREAM_DIVERGENCES.md`.

## D20. A DMA is a stream ✅

The source side (MM2S) reads the src pattern in traversal order and emits a stream. Padding is
applied on that side: for each dimension `i`, `pad_before[i]` zeros come before and
`pad_after[i]` zeros after, nested, so a padded index is zero if any of its coordinates is in a
pad zone. The destination side (S2MM) writes the dst pattern in traversal order from the stream.
The stream has `Π (src_size_i + pad_before_i + pad_after_i)` elements, and the dst pattern must
have as many (this refines D15).

## D21. Overlap within one DMA ✅

Let location `L` be read at stream step `i` (src) and written at step `j` (dst).

The write at step `j` carries the value read at step `j`, and reads happen in order, so every read
at `i ≤ j` precedes the write at `j`. The DMA is well defined on `L` when `i ≤ j` for every such
pair: it reads the old value.

When `i > j`, whether the read comes before or after the write depends on stream buffering and
timing, so it is a race inside the DMA. This is the condition under which a forward memmove is
safe.

When the dst pattern writes a location more than once (stride 0), the last write in traversal
order wins: the destination writes in order.

## D22. Ops the model does not interpret ✅

A race needs only footprints, not values.
- **linalg ops:** `ins` are read and `outs` are read and written.
- **`memref.copy`:** reads its source and writes its target.
- **Any other op with memref operands:** reads and writes the whole buffer of each operand. This
  is the conservative choice, which `air-dependency` also makes (`checkOperandReadOrWrite` returns
  `'w'` for an unknown op).

Values such ops produce are opaque: a deterministic function of the op and of what it read. The
determinism theorem does not depend on value semantics, so race-freedom and determinism are
still decided for programs containing them.

## D23. Non-constant offsets, sizes and strides ✅

These are needed, for example, for dynamic partial reconfiguration through control packets.
- **When running:** they are evaluated from function arguments and host arithmetic.
- **When checking races statically:** an access whose pattern is not constant is taken to cover
  its whole buffer, as `air::mayOverlap` does with an unknown range. Given concrete argument values,
  the check is exact for those values.

## D24. A DMA without `async` is synchronous ✅

"不带async的这个op是synchronous的op，计算顺序为program order": the host issues it in program
order and waits for it to complete. Everything after it is therefore ordered after it, as after
a blocking `air.wait_all` (D1).

## D25. What a synchronous op waits for ✅ (A)

Does a synchronous op (a blocking `air.wait_all`, a DMA without `async`) also wait for async ops
issued before it that it does not name? Either:
- **(A)** it waits only for the tokens it lists, as D1 says for `air.wait_all`; or
- **(B)** it acts as a full barrier, waiting for everything issued before it.

The model implements (A). It matches D1, and for race checking it is the conservative choice: if
the truth is (B), (A) can report a race that cannot happen, but never misses one.

## D26. `scf.for` (from the compute model)

`docs/AIRComputeModel.md`, "`scf.for` — loop-carried token dependencies":
- "`scf.for` iterations are logically sequential in program order, but the async token model
  allows controlled overlap between consecutive iterations."
- "An op in iteration N+1 that lists `%t_prev` in its `dependency` list does not begin until
  iteration N has signaled that token. An op that does **not** depend on `%t_prev` may begin
  before iteration N's `scf.yield` fires."

**Model:** iterations are instantiated in order. Each instance captures that iteration's
induction variable and the tokens its `iter_args` received. No other ordering between
iterations is added.

`air-dependency`'s outputs chain each iteration after the previous one. In the bounded check
(`check_loops.py`), every race it leaves is within one iteration, none across.

## D27. `scf.parallel` (from the compute model)

`docs/AIRComputeModel.md`: "`scf.parallel` regions (all instances concurrent, tokens reduced)".

**Model:**
- every point of the iteration space is instantiated, with no order between them;
- the result is the fold of the `scf.reduce` regions over the iterations' values, in iteration
  order. For the `air.wait_all` joins AIR uses, the order does not matter: the result waits for
  every iteration either way.

## D28–D32. Channels (layer 4)

Confirmed 2026-11-13:
- **D28.** `air.channel @C [4, 4]` is a bundle of 16 independent subchannels. `size` is the
  bundle's shape, not a capacity. Each subchannel is its own ordered stream.
- **D29.** A channel is a spatial, hardware, tile-to-tile stream:
  - without `broadcast_shape`, one-to-one;
  - with it, one put is consumed by N gets on different tiles at the same time, and until all N
    consume it, the put is back-pressured;
  - with `dest(%d)` (packet flow), routing is dynamic on a compile-time-determined spatial
    datapath, and each packet is delivered to the destination it selects.
- **D30.** "channel 是没有buffer的FIFO". When both ends of a transfer are async, the channel has no
  buffer: the put and the get transfer together, so a program can deadlock through
  backpressure. When either end is sync, the transfer is buffered without bound: "程序进行到put的
  时候，不会因为下一行马上就是get而导致backpressure".
- **D31.** Padding is the DMA concept of D20:
  - a put's padding inserts zeros into the stream;
  - a get's padding writes zeros to the padded positions of its destination, and the get takes
    only the other positions from the stream. For example, a get of 2 elements with
    `pad_before = 1, pad_after = 1` takes 2 from the stream and writes `[0, a, b, 0]`.
- **D33.** Endpoints on one subchannel in one direction must be totally ordered by token paths.
  Two that are not are an error, as a memory race is: which elements each one moves is undefined.
- **D34.** A subchannel carries a stream of elements; a get is one DMA receiving event.
  - Puts and gets need not pair one to one: one put of 8 elements may feed two gets of 4.
  - The i-th element put (in the token order of D33) is the i-th element got.
  - Nothing is wrong as long as there is no backpressure. Elements that no get takes keep an
    async put from completing.
- **D35.** A sync put or get is a blocking event (D24): it orders everything after it in program
  order.
- **D32.** Every channel type shares this semantics; none is refused for being of another type.

- **D36.** What a transfer orders, for memory:
  - (a) Within one transfer, a location read at stream step i and written at step j is well
    defined iff i ≤ j: the write at step j carries the value read at step j, and reads happen in
    stream order. A location read after it is written (i > j) is a race.
  - (b) A get's completion orders everything after it after the feeding put's reads of the
    elements it received: "get 完成，put 已经读完了它供给的那些元素，所以这样写是安全的。这是
    dependency canonicalization的transitive reduction的能成立的原因".

  Examples, `put async @C (%x[0..2))` and `get async @C (%x[k..k+2))` with no token between them:
  - `same_place` (k = 0): every element is read and written at the same step; race-free, x is
    unchanged.
  - `shift_down` (put reads x[1..3), get writes x[0..2)): x[1] is read at step 0, written at step
    1; race-free.
  - `shift_up` (put reads x[0..2), get writes x[1..3)): x[1] is written at step 0 and read at
    step 1; a race.

  `air-dependency` instead adds a token edge between such a put and get, which deadlocks the
  rendezvous of D30 (AIR-011).

`docs/AIRComputeModel.md`'s `depth` attribute (default 1) does not exist, and contradicts D30
(AIR-010).
