# MLIR-AIR async events in VeIR

This directory connects a bounded subset of [MLIR-AIR](https://github.com/Xilinx/mlir-air) to
VeIR. The subset is AIR's async dependency graph: `air.execute`, `air.wait_all` and
`!air.async.token`. It provides four things:

1. **Syntax.** Real AIR files, printed by `air-opt --mlir-print-op-generic`, are read into VeIR
   and printed back. `air-opt` accepts the result, and it is identical to the input after both
   are normalised.
2. **Executable semantics.** A function made of `air.execute`, `air.wait_all` and `arith`
   computes values. Each schedule its dependencies allow can be run, and every schedule can be
   enumerated.
3. **A proof.** The transitive reduction performed by `air-dependency-canonicalize` preserves
   reachability. It also leaves the set of executions unchanged, under any event semantics.
4. **A checker.** `sameReach`, proven sound, decides whether two versions of a function order
   their events identically. It is run on the output of AIR's own C++ pass.

## Status (2026-11-15, read first)

Every verdict `air-veir` prints now comes from one model, written in Lean, with its checks proven.
Three kinds of code are distinguished, and every claim in this directory should say which it rests
on:

| Kind | What | Files |
| --- | --- | --- |
| **Semantics (definitions)** | Events with dependencies (`Events.lean`); stream elements of channels and DMAs, their labels and when each may fire (`ChanSem.lean`: `En`, `Run`); what each label does to memory (`ChanMem.lean`: `MemSpec`); the AIE target's step function (`Aie.lean`: `Model.steps`, `settle`; `AieCert.lean`: `post`, `Reach`) | as listed |
| **Proven (Lean kernel, no `sorry`)** | the theorems below, about those definitions | `DepGraph`, `Events`, `Race`, `Determinism`, `Schedule`, `Pattern`, `ChanSem`, `ChanMem`, `ChanFast`, `ChanDecide`, `AieCert` |
| **Trusted glue (tested, not proven)** | turning IR into the model: events, loops and hierarchy instances (`Instance.lean`), channel endpoints (`Channels.lean`), elements and footprints (`ChanGlue.lean`), rounds of instantiation on run-time control flow (`Running.lean`), the AIE model from `aie.device` (`Aie.lean`: `extract`); running atomic event bodies (`finishExecute`, `finishDma` for run-time patterns) | as listed |

What the proven checks give, for any program the glue accepts:

| Verdict | Proven by | Meaning |
| --- | --- | --- |
| no deadlock | `Chan.checkH_true`, `Chan.completes_from_anywhere` | an execution completes, and from every state an execution reaches, one still can |
| DEADLOCK | `Chan.checkH_false` | no execution completes |
| race-free, outcome | `Chan.raceFree_of_racesOkE`, `Chan.outcome_uniqueE` | every complete execution ends with the printed memory (given effects framed by footprints) |
| race, second execution | `Chan.checkH_true` on the second execution | both executions are valid; that they end differently is computed |
| control flow on device values (D59) | `Chan.decision_reads` | every execution, at each decision, reads the value the program was instantiated with |
| AIE: outcomes, deadlock, fault | `Aie.Cert.parents_sound` | each is reached by an execution of the model |
| AIE: "exactly the reachable states" | `Aie.Cert.exact` | the listed verdicts are all of the model's |

Covered: `air.execute`, `air.wait_all`, tokens, `scf.for`/`scf.parallel`, `affine.for`,
`scf.forall`/`affine.parallel`,
`affine.load`/`affine.store`, `scf.if`/`affine.if`/
`scf.index_switch`, `air.dma_memcpy_nd` (element by element when its pattern is known, D20/D21),
channels (D28-D36, D51), broadcast (D29, D53), unordered puts into one stream (D52, one model per
order), `air.channel.issue` (D54, D58), `air.refeed_count` (D61), per-launch streams (D56), run-time offsets (D23; per input, D62), event
results as memory (D4, D57), `memref.global`, unranked memrefs as bare pointers (D63), whole views as transfer ends, hierarchy ops and ranks
(D37-D49).

Control flow decided by values events compute (D59, D60) is instantiated while running, for the
input given (`--args` for scalars, `--mem` for memref contents): rounds of instantiation propose
the values (`Running.lean`, not proven), and the whole program they end with is checked. When it
completes and is race-free, `Chan.decision_reads` proves every execution reads the values used;
otherwise the output says this is not established, and its verdicts are for that control flow.

Control flow decided by a scalar argument not given (`--args`, or `?` in it) is checked for every
value of the argument when only comparisons with constants read it (`ArgSplit.lean`): `races`
splits its values into classes (each constant, the gap above each, the gap below all), checks the
program instantiated with one value of each class, and says whether every class is clean. An
argument that anything else reads (an offset, a loop bound) is not split, and the branch is refused
as before. An offset of a channel transfer that a scalar argument not given decides is any value:
the transfer is taken to touch its whole buffer (D23), so the verdicts hold for every value, and
`races` notes that a race reported on such an access may occur for none. A size the argument
decides has no finite cover (the number of elements decides how the streams balance): it is tried
with the values `ArgSplit.sizeSamples` (1, 2, 3; sizes are positive, decided 2026-11-20), each
verdict proven for its value; a value not clean refutes "for every value", and otherwise only the
values tried are checked.

Refused, pending a decision or work:
- an access pattern on a view at a non-zero offset (D14; at offset 0 it is accepted, D14b);
- a slot fed both by a broadcast put and by other puts;
- programs over 20000 events; run-time offsets over big buffers may time out (the race scan treats
  such an access as the whole buffer, element by element).

Not verification, and not to be read as such: the Python scripts (`Test/Air/bounded/*.py`,
`sweep_dependency.py`) only generate inputs and count verdicts; their recorded numbers before
2026-11-14 come from the earlier, unproven checkers and must be re-run.

## What is and is not established

Each claim is listed at its own level; they do not imply one another.

| Claim | Status |
| --- | --- |
| AIR text can be imported | Yes. 140 of 473 AIR test modules round-trip identically, 0 differ. 332 are refused for VeIR limitations outside this work, and 1 hits a VeIR `llvm` bug (see [Results](#results)). |
| The supported subset can be interpreted | Yes, by `Program.finishEvent` and `air-veir run`. |
| The theorems pass Lean's kernel | Yes. No `sorry`, no `native_decide`, no new axioms (see [Theorems](#theorems)). |
| The `air-dependency-canonicalize` output passes the checker | Yes, on every AIR test file in the subset (4 of 4), and on the fixtures. Only for those instances. |
| Layer 2: events' memory footprints, races, DMA semantics | DMAs with known patterns are element streams in the proven model (`ChanSem`, `ChanMem`); D20/D21 follow from it. Atomic events (bodies, DMAs with run-time patterns) are framed by their footprints by assumption: the glue's footprints are **not proven** to frame its effects. |
| `air-dependency` makes programs race-free | **No**: every input of `check_dependency.py` is race-free (synchronous DMAs, D24), and `air-dependency` turns 30 of 196 (2 DMAs) and 922 of 2,744 (3 DMAs) of them into racy programs (AIR-007). |
| Layer 4: channels (rendezvous, element streams, deadlocks) | Semantics in Lean (`ChanSem.lean`), deadlock decided both ways and shown schedule-independent, races and determinism proven (`ChanMem`, `ChanFast`). The earlier AND-graph analysis was unproven against the semantics and is removed; under D51 it misjudged mixed sync/async transfers. Which put feeds which get is computed by trusted glue (`Channels.lean`, `ChanGlue.lean`). |
| `air-dependency` keeps channel programs deadlock-free | **No**: of the 200 synchronous, deadlock-free channel programs of `check_channels.py`, `air-dependency` makes 93 deadlock (AIR-011). 48 of them need no edge at all (D36(a)); 45 have no correct all-async form. |
| Layer 5: `air.launch`/`segment`/`herd`/`rank` | Executable (`Instance.lean`, `hierarchyInstance`): each op is a start event, its body once per instance, and an end event (its token). The graph and race theorems apply to the instances. |
| `air-dependency` keeps hierarchy programs deadlock-free | **No**, under D38 (i): mlir-air's own `channel_drain_hierarchy.mlir` deadlocks after it (AIR-012); the edge comes from a general rule. |
| `air-dependency-canonicalize` is correct | **Not claimed.** The C++ pass works on a larger graph (DMA, channels, hierarchy, loops) than the one modelled here. |
| The extraction from IR matches the model | **Not proven.** It is tested. `Program.steps_reduce_iff` is about the extracted `Program`, not about the IR. |
| `air-veir reduce` is correct | **Not proven.** It is checked per run: `sameReach` before printing, then re-parse and re-verify by VeIR and `air-opt`. |

## Versions

| Component | Revision |
| --- | --- |
| VeIR `main` this branch is based on | `d8350566f978385fcfb144f45279760354ee2f2a` (2026-11-13) |
| VeIR PR #1938 head | `dd35a5cae306e6516be8d15f85d12f49692e642f`. Its base is PR #1937 (`eef529e64`); the merge base with `main` is `543e5179e`. |
| Lean | `leanprover/lean4:v4.35.0-rc4`, as pinned by `lean-toolchain` |
| MLIR-AIR | `9b81b5de0b5714839a073fa80e8b08611f864b09`. The `air-opt` binary was built from that checkout on 2026-10-14. The one AIR commit since then touching these paths, `6b9d934e6` (AIRToAIE lock fix), does not change the dialect or the canonicalizer. |
| lit / filecheck | 18.1.8 / 1.0.3, through `uv` as VeIR's `Makefile` does |

## Commands

Every command here was run as written. Paths are relative to the VeIR root.

```bash
lake build                        # builds Veir, veir-opt, air-veir, ...
lake test                         # Lean unit tests, including UnitTest/Air.lean
uv run lit Test/Air -v            # the AIR lit tests (16)
uv run lit Test/ -q               # all of VeIR's lit tests
AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh            # checks that need air-opt
AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh --sweep /path/to/mlir-air/mlir/test
AIR_OPT=/path/to/air-opt Test/Air/sweep_dependency.py /path/to/mlir-air/mlir/test/.../*.mlir   # air-dependency, then races/deadlocks
```

`air-veir --help` describes the tool:

```bash
air-opt in.mlir --mlir-print-op-generic --mlir-print-local-scope -o in.generic.mlir
.lake/build/bin/air-veir graph  in.generic.mlir   # events, edges kept by the reduction, unordered reads
.lake/build/bin/air-veir run    in.generic.mlir   # values, and agreement across all allowed orders
.lake/build/bin/air-veir races  in.generic.mlir   # races, bounds, channel errors, deadlock certificates
.lake/build/bin/air-veir template in.generic.mlir  # phase 2a: the loop template and its certificate
.lake/build/bin/air-veir reduce in.generic.mlir > out.mlir
air-opt out.mlir                                  # AIR re-verifies it
.lake/build/bin/air-veir check  in.generic.mlir out.mlir
air-opt in.generic.mlir -air-dependency-canonicalize --mlir-print-op-generic > cxx.mlir
.lake/build/bin/air-veir check  in.generic.mlir cxx.mlir   # translation-validate AIR's pass
```

## Source map

| Layer | AIR | VeIR, existing | VeIR, new |
| --- | --- | --- | --- |
| Op/type definitions | `mlir/include/air/Dialect/AIR/AIR.td` (`air_ExecuteOp`, `air_ExecuteTerminatorOp`, `air_WaitAllOp`), `AIROpBase.td` (`air_AsyncToken`) | `@[opcodes]` inductive plus `#generate_dialect` (`Veir/Meta/OpCode.lean`), dispatch in `Veir/GlobalOpInfo.lean` | `Veir/Dialects/Air/OpInfo.lean`, registered in `Veir/OpCode.lean` and `Veir/GlobalOpInfo.lean` |
| Type parsing | `airDialect::parseType` (`AIRDialect.cpp`): `async.token` | `parseOptionalUnregisteredSingletonType` (the LLVM parameterless types use it) | `!air.async.token`, and a verbatim `memref<…>`, in `Veir/Parser/AttrParser.lean` |
| Generic parser | — | `Veir/Parser/MlirParser.lean`. Unregistered ops become `builtin.unregistered`, keeping their name and properties. Regions, block arguments and discardable attributes are preserved. | — |
| Structure verifier | ODS constraints and `ExecuteOp::verify` | `verifyLocalInvariants`, plus the dominance check in `Veir/Verifier` | `Air.verifyLocalInvariants` |
| Interpreter | — | `Veir/Interpreter/CTreeInterpreter.lean` (CFG); `Arith.interpretOp'` | `Veir/Air/Extract.lean`: `extract`, `Program.finishEvent`, `Program.sem` |
| The pass | `AIRDependencyCanonicalize` → `dependencyCanonicalizer` (`mlir/lib/Util/Dependency.cpp`) → `DirectedAdjacencyMap::applyTransitiveReduction` | — | `DepGraph.reduce` (`Veir/Air/DepGraph.lean`), `Program.reducedOperands` and `applyReduction` (`Veir/Air/Rewrite.lean`) |
| Memory, DMA, loops | `air.dma_memcpy_nd`, `scf.for`/`scf.parallel` at host level; `AIRDependency.cpp` | — | `Veir/Air/MemProgram.lean` (decoding), `Veir/Air/Instance.lean` (instantiation, memory semantics, footprints) |
| Channels | `air.channel`, `air.channel.put`/`get` (`AIR.td`); `AIRDependency.cpp` adds their token edges | — | `Veir/Air/Channels.lean` (streams, AND-graph, transfers, deadlocks) |
| Proofs | — | — | `Veir/Air/DepGraph.lean`, `Events.lean`, `Pattern.lean`, `Race.lean`, `Determinism.lean`, `Schedule.lean` |
| Driver and tests | `mlir/test/Dialect/AIR/air_execute.mlir`, `air_wait_async.mlir`, `mlir/test/Transform/AIRDependencyCanonicalization/prune_redundant_edges.mlir` | `Exe/VeirOpt.lean`, lit (`Test/lit.cfg`) | `Exe/AirVeir.lean` (`air-veir`), `Test/Air/`, `UnitTest/Air.lean` |

## PR #1938, read at `dd35a5cae`

Title: "feat(seq): simulate a hw.module as a synchronous netlist", by `stephenneuendorffer`. It is
open, and the ninth of a stack. Its own diff adds `Veir/Interpreter/Netlist.lean` (359 lines) and
`UnitTest/Netlist.lean` (518 lines).

1. **Defining ops, types and attributes.** #1938 does not do this; it uses the `seq`, `hw` and
   `comb` dialects already on `main`. The recipe followed here is the one the `tensor` dialect
   used (`b7048ac2f`).
2. **Generic parser.** Unchanged by #1938. `Netlist.lean` reads the parsed `WfIRContext` with
   `getOpType!`, `getOperands!` and `getProperties!`.
3. **Where things live.** The parser and verifier are unchanged. The driver is
   `Veir.Netlist.Info.of`, `settle`, `stepClock` and `outputs`. Tests are `#guard_msgs`/`#eval!`
   in `UnitTest/Netlist.lean`. There is no rewriter and no proof.
4. **Kind of support.** An executable simulator: syntax plus an interpreter. It contains no
   theorems.
5. **Circuit semantics.** A *stateful synchronous* circuit. On each clock edge it settles the
   combinational ops in program order, latches the `seq.firreg`s on the ticked clock, applies
   enabled memory writes in port order, and settles again. It is deterministic and has no
   concurrency between events: one clock domain fires at a time. That is the wrong model for AIR
   tokens. An AIR event may start when its dependencies are done, but need not, and independent
   events may overlap. So the semantics here is a nondeterministic transition system (`Step`), not
   a clocked function.
6. **`sorry`/axioms.** None in its code. Its description says it calls `Comb.interpretOp'`
   directly so that a theorem about a netlist does not inherit the `bv_decide` axioms of the LLVM
   memory model through `Veir.interpretOp'`.

**What was reused:**
- a dedicated driver beside the CFG interpreter, because AIR's execution model is not a CFG walk;
- direct dialect dispatch (`Arith.interpretOp'`, not `Veir.interpretOp'`), for the axiom reason above;
- refusing unsupported constructs rather than approximating them, with a test per refusal;
- the bounded linked-list walk over a block's operations.

**What was not reused:** the netlist's synchronous state model, as explained in item 5.

## Support matrix

| Op / type | Parse and print | Structure check | Execute | Proof |
| --- | --- | --- | --- | --- |
| `!air.async.token` | registered; no flag needed | operand/result positions checked | event identity | `DepGraph`, `Events` |
| `air.execute` | registered | token operands; result #0 a token; one region with one block (mirrors AIR) | its body runs when it finishes; results published then | via `Program.sem` |
| `air.execute_terminator` | registered | inside an `air.execute` | yields the results; the count and types must match the op, else `extract` refuses | — |
| `air.wait_all async` | registered | token operands; at most one token result | an event with no effect | yes |
| `air.wait_all` (blocking) | registered | as above | an event that every later event waits for (implicit edges, never removed) | `steps_between_iff` |
| `arith.*` in an `air.execute` | VeIR's `arith` | VeIR's | `Arith.interpretOp'` | abstracted: any `Sem` |
| `arith.constant` in the function | VeIR's `arith` | VeIR's | evaluated before any event | — |
| `memref<…>` | verbatim, no meaning | none | refused | — |
| `air.dma_memcpy_nd async` | unregistered; round-trips | operand segments and patterns decoded | stream semantics with padding (D20); overlap and repeated writes (D21); bounds checked | footprints (D14, D20); races through `raceFreeB_iff` |
| `air.dma_memcpy_nd` (no `async`) | round-trips | — | synchronous (D24): orders everything after it; waits only for its own dependencies (D25, pending) | footprints |
| `memref.alloc`, `dealloc`, `load`, `store` in `air.execute`; host `memref.alloc` | unregistered; round-trips | — | buffers, `undef` contents, use-after-free checked (D17) | footprints |
| `memref.copy`, `linalg.*` and any other op in `air.execute` | unregistered; round-trips | — | opaque values; read/write of whole operand buffers (D22) | footprints |
| `affine_map<…>`, `affine_set<…>` | verbatim, no meaning | — | — | — |
| `scf.for`, `scf.parallel` (host level) | unregistered; round-trips | — | instantiated iteration by iteration (D26, D27); bounds must be known (`--args`) | graph and race theorems apply to the instances |
| `scf.forall` (no `shared_outs`), `affine.parallel` (no reductions) (host level) | round-trips | — | as `scf.parallel` (D27): every point concurrent, a blocking op orders only its iteration; `affine.parallel` bounds are max/min per dimension group | graph and race theorems apply to the instances |
| `affine.for` (host level) | round-trips | — | as `scf.for` (D26), with upstream bounds: the largest result of `lowerBoundMap`, the smallest of `upperBoundMap`, a constant `step` | as `scf.for` |
| `affine.load`, `affine.store` | round-trips | — | as `memref.load`/`store`, at the element their `map` computes (at host level a blocking event, D45) | footprints |
| `air.channel` declarations | `--allow-unregistered-dialect`; round-trips (after the VEIR-002 fix) | — | bundles of subchannels (D28); `broadcast_shape` (D29) | — |
| `air.channel.put`/`get`, async and sync | `--allow-unregistered-dialect`; round-trips | — | element streams per subchannel (D34); rendezvous when both ends are async, buffered otherwise (D30); padding (D31); D33 ordering checked; memory ordered by transfers (D36) | deadlock and schedule certificates (`Schedule.lean`); races through `raceFreeB_iff` on the graph with transfer nodes |
| `air.launch`, `air.segment` (nested too), `air.herd`, `air.rank` | `--allow-unregistered-dialect`; round-trips | operand segments, block arguments | start event, body per instance (all concurrent; launch instances must not communicate, D37), end event = token (D38); dependencies gate every instance, no result = blocking, blocking inside is per instance (D39); allocs per instance, operands by reference (D40); token operands are the outer events (D42) | via the instantiated graph |
| `air.universe.alloc` | round-trips | — | a resource; no effect on ordering | — |
| any other op without `async` (`memref.dealloc`, `memref.load`/`store`/`copy`, `linalg.*`, `func.call`, ...) at host level or in a hierarchy body | round-trips | — | a blocking event whose body is the op (D45), so `air-dependency`'s *input* can be checked too | footprints |
| `scf.if`, `affine.if`, `scf.index_switch` | round-trips | — | the region the condition selects runs, as upstream MLIR defines it; the condition must be known before running (tile ids, constants, induction variables), otherwise refused | via the instantiated graph |
| `affine.apply` | round-trips | — | evaluated from the verbatim map (`Affine.lean`: `floordiv`, `ceildiv`, `mod`) when its operands are known, `undef` otherwise | — |
| non-integer `arith.constant` (float, dense) | refused by VeIR (VEIR-004); `air-veir` renames them to `veir.opaque_constant` | — | opaque values (D22) | — |
| `air.custom` | round-trips | — | an event (async with a result, blocking without); reads and writes each memref operand whole, opaque values (D49) | footprints |
| `air.refeed_count` on a put, its channel or the `memref.alloc` of the buffer it sends | round-trips | — | N sends of the put's pattern, in order (D61); a get is unaffected; a counted buffer sent by more than one put is refused | via the instantiated graph |
| `memref.alloc {air.symmetric}`, cross-rank DMA (`src_rank`/`dst_rank`), `air.translate` | round-trips | — | one buffer per rank as a family; a cross-rank side or a translate addresses rank R's buffer (D49); one-dimensional `air.rank` only | races across ranks through the instantiated graph |
| `affinity`/`concurrency` lists | `--allow-unregistered-dialect`; round-trips | none | **refused with a diagnostic** (D44) | — |

## Semantics

Every decision about what an AIR construct means, and whether an AIR developer has confirmed it,
is in [`SEMANTICS.md`](SEMANTICS.md). Read it before relying on a theorem.

**Input subset.** A `func.func` with one block, containing only:
- `air.execute`, `air.wait_all`, `arith.constant`, and a final `func.return`;
- inside each `air.execute`: `arith` ops and the terminator, with no nested regions or block arguments;
- body operands that are body-local values, top-level constants, or results ≥ 1 of other `air.execute`s.

Tokens must be results of `air.execute`/`air.wait_all` in the same block. `extract` refuses
everything else, naming the operation.

**Well-formedness.** Events are numbered in program order. Every dependency names an earlier
event (`DepGraph.Forward`). SSA dominance guarantees this, `extract` re-checks it, and `air-veir`
checks `forwardB` before using a graph. A cycle is a use before its definition: VeIR's dominance
verifier refuses it, as `air-opt` does.

**Event model** (`Veir/Air/Events.lean`). Each event is `pending`, then `running`, then `done`.
- `start v` is allowed when `v` is pending and every event it waits for is done. Being allowed
  does not oblige anything to happen, and independent events may start in any order or overlap.
- `finish v` is allowed when `v` is running, and only then is its token signalled.
- What starting and finishing *do* is a parameter, `Sem σ`: two relations on an opaque state `σ`.
- For AIR programs, `Program.sem` sets `σ = RunState`, which holds the values computed so far and
  the first fault. Starting does nothing. Finishing an `air.execute` runs its body and publishes
  the values it yields.

**Observable behaviour.** The set of traces: label sequences (`start v`/`finish v`), each paired
with the configuration it reaches. `air-veir run` shows the values in program order and whether
every allowed finishing order computes the same values.

**Faults are explicit.** Reading a result of an `air.execute` that has not finished is a fault, not
a stale value. Such a program is wrong (`SEMANTICS.md`, D4), and `air-veir graph` warns statically
about any read not ordered by the tokens. `func.return` does not wait for outstanding events (D5).

**Not modelled:**
- (layers 2-4 add memory, DMA, host-level loops and channels; see `SEMANTICS.md`)
- views other than those folded into a DMA pattern;
- loops whose bounds are not known;
- spatial scopes (`launch`/`segment`/`herd`) and their instances;
- resources and timing;
- host program order, beyond blocking `air.wait_all`;
- interleaving *within* an event body. Effects happen at the start and finish steps, so a body
  that interleaves with another at a finer grain needs those steps modelled as separate events.

## Theorems

All are in `Veir/Air/*.lean`, checked by Lean's kernel, with no `sorry`. `UnitTest/Air.lean` pins `#print axioms` for each:
- `propext` and `Quot.sound` for all of them;
- `Program.steps_reduce_iff` also uses `Classical.choice`, through the IR types in its statement.

None uses `Lean.ofReduceBool` or an axiom of this development.

| Theorem | Statement | Assumption |
| --- | --- | --- |
| `DepGraph.size_reduce` | the reduction keeps the same events | — |
| `DepGraph.reduce_sub` | it only removes edges | — |
| `DepGraph.reach_reduce_iff` | `Reach g.reduce u v ↔ Reach g u v` | `g.Forward` |
| `DepGraph.reach_between_iff` | any `h` with `g.reduce ⊆ h ⊆ g` has `g`'s reachability | `g.Forward` |
| `DepGraph.reachB_iff` | the executable `reachB` decides `Reach` | `g.Forward` |
| `DepGraph.sameReach_sound` | `sameReach g h = true` → same events, both forward, same `Reach` | — |
| `steps_iff_of_reach` | two forward graphs with the same reachability admit the same traces, from any configuration where started events' dependencies are done, under **any** `Sem` | stated |
| `steps_reduce_iff` | `Steps g.reduce sem init t c ↔ Steps g sem init t c` | `g.Forward` |
| `steps_between_iff` | the same for any graph between `g.reduce` and `g` (the form the rewrite with blocking waits needs) | `g.Forward` |
| `steps_of_sameReach` | a checker `true` gives the same traces | — |
| `Program.steps_reduce_iff` | the AIR instance: same values and faults for an extracted program | `p.graph.Forward` |
| `Program.reducedGraph_between`, `Program.steps_reducedGraph_iff` | the graph `air-veir reduce` produces lies between `g.reduce` and `g`, so it admits the same executions | `p.graph.Forward` |
| `progress` | every forward graph can run to completion, under any semantics whose steps can always be taken (checklist C2) | `g.Forward`, total `Sem` |
| `positions` (`Pattern.lean`) | the elements an access pattern touches, in traversal order (D14); `length_positionsFrom`: there are `Π sizes` of them (D15) | — |
| `positions_foldFixed` | folding `memref.subview` into a pattern by moving its whole offset into a leading size-1, stride-1 dimension touches exactly the subview's elements, in order | — |
| `positions_foldAsAIR_of_unitSteps`, `foldAsAIR_wrong` | AIR's current fold is right when every step is 1, and wrong for `subview %m[4] [4] [2]` (AIR-009) | — |
| `raceFreeB_iff` (`Race.lean`) | the executable race checker decides `RaceFree`: every conflicting (RAW/WAR/WAW, overlapping) pair is ordered by a token path | `g.Forward` |
| `raceFree_reduce_iff`, `raceFree_of_sameReach` | the transitive reduction, and any rewrite `check` accepts, neither creates nor hides a race | `g.Forward` |
| `effects_commute` (`Determinism.lean`) | effects framed by non-conflicting footprints commute | `Framed` |
| `deterministic` | in a race-free program with framed effects, every complete execution ends with the same memory (checklist C3, event level) | `g.Forward`, `Framed`, `RaceFree` |
| `scheduleB_sound` (`Schedule.lean`) | a checked firing order of the start/finish AND-graph is a complete schedule: the program can run to completion (C2, layer 4) | — |
| `Stuck.never_fires`, `no_schedule_of_stuckB` | a checked stuck set never fires, so no schedule exists: the program deadlocks | — |
| `reachFast_eq` (`DepGraph.lean`) | the bit-set rows `reachRows` answer exactly as `reachB`; `reachB` alone is exponential on diamonds | — |
| `sameReach_eq_sameReachFast`, `races_eq_racesFast` | `@[csimp]`: compiled code runs the polynomial versions, the theorems speak of the originals | — |
| `cyclic_simultaneous_drop_unsound` (UnitTest) | on a cycle, deciding edges independently and dropping them together loses reachability | — |
| `Chan.En.mono` (`ChanSem.lean`) | a label enabled stays enabled as others fire | — |
| `Chan.Run.replay`, `Chan.completes_from_anywhere` | deadlock does not depend on the schedule: if one execution completes, every reachable state can still complete | — |
| `Chan.check_true`, `Chan.check_false` | the reference checker decides completion both ways | — |
| `Chan.HB.before` (`ChanMem.lean`) | every execution respects `HB` | — |
| `Chan.deterministic` | race-free (by `HB`) channel programs with framed label effects end every complete execution with the same memory | `WF`, `LFramed`, `RaceFree` |
| `Chan.MemSpec.framed` | the element labels' effects (read into flight, write at each destination) are framed by their footprints | events framed |
| `Chan.checkH_true`, `Chan.checkH_false` (`ChanFast.lean`) | the fast checker on a proposed execution is right both ways | — |
| `Chan.raceFree_of_racesOk` | the location-by-location race scan is sound | `HBEdges` (built in) |
| `Chan.raceFree_of_racesOkE` | the same scan with orders from the event graph (`finishersL`, `startersL`, `hb_finish_start`) and short label paths (`localReach`): no matrix over every label | — |
| `Chan.scanOk_sound` | one location's scan orders every conflicting pair, by transitivity | — |
| `Chan.outcome_uniqueH` | the end-to-end statement of the fast checks | `WF`, `LFramed` |
| `ArgSplit.reps_cover` | for every value in an argument's range, one of the values tried compares with every constant (`<`, `=`) as it does | — |
| `ArgSplit.eval_invariant`, `eval_invariant'` | then `arith.cmpi`'s signed and equality predicates (`IntPred.eval`) give the same result on both, the argument on either side | — |
| `ArgSplit.combos_cover` | with several arguments, every tuple of values has its classes among the tuples tried | — |
| `Aie.Cert.parents_sound`, `Cert.closed_complete`, `Cert.exact` (`AieCert.lean`) | an exploration's states are reachable; closed, they are all the reachable states | — |

"Same traces" is the strongest notion here. It implies the same finishing orders (linear
extensions) and the same final states, and holds for effectful bodies too, since `Sem` is
arbitrary. It does **not** say that two AIR programs are equivalent once loops, channels,
resources or memory are involved. Those are outside the model.

## Trust boundary

**Checked by Lean's kernel:** the theorems above, about `DepGraph`, `Steps` and `Program.sem`.

**Trusted:**
- VeIR's parser and printer;
- `extract`, which turns IR into a `Program` (tested, not proven);
- `Program.finishEvent` (an executable `arith` evaluator, run through `Arith.interpretOp'`);
- the Lean compiler, which runs `air-veir`.

**Layer 2's executable model** (`extractMem`, `footprints`, `finishMem`) is trusted, and tested.
The theorems assume the effects are framed by the footprints; that the implementation is, is
checked exhaustively, not proven.

**The model built from IR** (`analyzeChannels`, `chanModel`, `labelFp`, `fireLabel`: which put
feeds which get, element locations, footprints, concrete effects) is trusted, and tested. The
verdicts on the model are proven: `checkH`, `racesOkE`, `outcome_uniqueE`. D36 is not assumed; it
follows from the element semantics.

**Chunked transfers (phase 1, `SCALE_DESIGN.md` §2).** `races`, `run` and `outcome` check the
channel model on chunks of consecutive elements when the chunking (`Chan.validB`) and the chunk
condition (`Chan.condBR`) check; that the verdicts hold of the element model is proven
(`Chan.chunked_soundR`, `Chan.chunked_deadlock`, `Chan.outcome_uniqueCR`). Nothing is added to the
trusted base: the chunking itself is checked, not trusted. Footprints are ranges (`labelRFp`,
`Chan.racesOkRangeE`); that they stand for the positions `labelFp` lists is part of the model, as
`labelFp` was.

**Loop templates (phase 2a, `SCALE_DESIGN.md` §3.1).** For a function whose loop bounds are not
known or that is too large to instantiate, `races` checks a template instead: the certificate and
`LoopCert.raceFree_of_certOk` (race-freedom for every trip count of the symbolic loops) are proven.
That the template stands for the program (`LoopCert.Realizes`: its edges are dependencies, each
label's accesses lie in its covering instance's, places in memory identify buffer instances, and
conflicts on stream slots or within one event are ordered by the stream) is trusted: the template
is generalized from a sample with each symbolic loop run three times (`LoopTemplate`), and is not
cross-checked against a full instantiation (decided 2026-11-18).

**Branches on scalar arguments (`ArgSplit.lean`).** That the values tried cover every value of
the arguments, comparison by comparison, is proven (`reps_cover`, `eval_invariant`,
`combos_cover`). That only those comparisons read the arguments (`ArgSplit.plan`: through the
`args` of launch, segment and herd and sign-extending casts, into `arith.cmpi` with `eq`, `ne`,
`slt`, `sle`, `sgt`, `sge` against a constant, or `scf.index_switch`), so that two values of one
class instantiate the same program, is trusted, as `Instance` is. An `i1` argument is tried with
both values.

**The AIE model** (`Aie.extract`, `Model.steps`, `Model.settle`) is the definition of T1-T10;
that it says what `AIE_SEMANTICS.md` says is not proven. Explorations are checked
(`Cert.parentsB`, `Cert.closedB`); partial-order reduction is not proven, so verdicts found with it
are only claimed reachable, never complete.

**Checked per run instead of trusted:** the graph that `air-veir reduce` intends to produce
(`reducedGraph`) is proven correct. That `applyReduction` turns it into IR is not.
`applyReduction` rewrites operand arrays on a raw `IRContext` without maintaining use-lists. Proving that well-formed would need new VeIR invariants
for operand removal, which are not in VeIR yet. Its output is only printed, and is then
- re-parsed and re-verified by VeIR (`veir-opt`) and by `air-opt`;
- compared by `sameReach`, whose soundness is proven;
- checked to have changed nothing but dependency operands (`air-veir check`).

## Results

**Lean.** `lake test` passes, including `UnitTest/Air.lean`.

**lit.**
- `uv run lit Test/Air`: 16 of 16 pass.
- `uv run lit Test/`: 1601 passed, 8 unsupported, 2 expectedly failed, 0 failed.

**AIR integration** (`air-integration.sh`, 2026-11-13):
- The three fixtures round-trip identically after `air-opt` normalisation, including `id`
  attributes, `operandSegmentSizes` and `INT64_MIN` static offsets.
- For the two fixtures in the subset, both `air-veir reduce` and `air-dependency-canonicalize`
  pass `check`.
- `prune_redundant_edges.mlir` is refused at its `air.launch`.

**Sweep of AIR's `mlir/test`** (631 files):
- 158 skipped: expected-error tests, split-input files, or not accepted by `air-opt`.
- Of the remaining 473:
  - 140 round-trip identically and 0 differ (196 since `affine_map` is read; 276 refused);
  - 332 are refused by VeIR's parser. Each refusal was classified from its error location:
    - 164 for an untyped integer in an array attribute (for example `air.channel … size = [1]`);
    - 85 for `affine_map<…>`;
    - 61 for a float or dense `arith.constant`;
    - 21 because VeIR's `arith` verifier rejects `index` operands to `arith.muli`, `arith.addi`
      and `arith.extsi`;
    - 1 other;
  - 1 is not re-verified by `air-opt`. VeIR drops `llvm.load`'s `ordering` property; see below.
- 4 files fall in the semantic subset. `air-dependency-canonicalize`'s output passes the checker
  on all 4.

**Tests.** Every requirement has a test:

| Requirement | Where |
| --- | --- |
| real AIR import/export, re-verified by AIR | `roundtrip.mlir`, `air-integration.sh` |
| a positive interpreter test | `redundant.mlir`, `blocking_wait.mlir`, `reduce_real.mlir` |
| `A→B→C` + `A→C`: `A→C` dropped | `redundant.mlir` |
| a necessary edge removed by hand: rejected, with a counterexample order and a fault | `required_edge.mlir` |
| independent events: no edge added; serialising them is rejected | `independent.mlir` |
| bad token, cycle, unsupported op and type, each with a clear diagnostic | `diagnostics.mlir` |
| nested scopes (`air.launch`, `scf.for`) refused | `diagnostics.mlir` |
| why acyclicity matters | `UnitTest/Air.lean` |

## Findings

- **AIR verifier bug** (confirmed, `SEMANTICS.md` D8). `air.execute -> (index)` whose terminator
  yields an `i32`, or nothing, is accepted by `air-opt` (`ExecuteOp::verify` checks only that the region is non-empty). VeIR's
  structure check mirrors AIR. The semantics refuses the op (`Test/Air/Inputs/terminator_mismatch.mlir`).
- **AIR doc/implementation mismatch.** `docs/AIRComputeModel.md` describes `!air.token`,
  `air.token.alloc` and `affinity`/`concurrency` token lists. The dialect implements
  `!air.async.token` and a single `async_dependencies` list. The former are planned (D9). This work
  follows the implementation; `!air.token` is refused (`diagnostics.mlir`).
- **`air-dependency-canonicalize` drops every outgoing edge of an `air.execute` whose body has
  two or more ops** (found by bounded exhaustive checking). An earlier version of this note
  blamed bodies that read other executes' results; that was a confound, since such reads add an
  op to the body. The root cause, read in `mlir/lib/Util/Dependency.cpp`:
  - `addVertexFromExecuteOp` builds one vertex per body op. Only the first two vertices point back
    to the execute (`pointer_op`); later ones, including the terminator, point to their own op.
  - Outgoing edges leave from the terminator vertex (`getVertexFromOp(…, "back")`).
  - `fillAIRDepListUsingGraphTR` skips a source vertex whose op is not an `AsyncOpInterface`.

  So with two or more body ops, every edge out of the execute is lost when the reduced graph is
  written back. Multi-op execute bodies occur in 33 of 1,817 executes in AIR's `mlir/test`. A fix
  is not yet written or tested. Tracked locally as AIR-002 in `~/air-issues`.
- **`air-dependency-canonicalize` run time is superlinear in the number of functions in a module**:
  1.5 s, 7 s and 42 s for 1000, 2000 and 4000 small functions. Hypothesis, not profiled: the
  pass's `dependencyContext` (`dep_ctx`, with its `op_to_v`/`op_to_g` maps) is a member of the
  pass and is not reset between functions.
- **AIR pass behaviour.** `air-dependency-canonicalize` also removes `id` attributes from
  non-DMA/channel/hierarchy ops, and reorders dependency operands. `check` compares reachability,
  so neither matters to it.
- **VeIR, not AIR:**
  - `llvm.load` loses its `ordering` property in a round trip, so an atomic load is printed as a
    plain one (`mlir/test/Conversion/AIRToROCDL/sym_atomic_syncscope.mlir`).
  - VeIR rejected an integer literal without a type in an attribute (`size = [1]`), which MLIR
    reads as `i64`. That blocked every `air.channel` declaration (VEIR-002). Fixed on this branch
    for list, array and dictionary elements only, because one VeIR test does require a typed
    literal elsewhere (`!mod_arith.int<17>` is an error). An earlier version of this file wrongly
    said no test asserted the rejection.
  - VeIR's `arith` verifier rejects `index` operands to integer binary ops
    (`arith.muli`: "Expected operand 0 to have integer type"). AIR's address arithmetic uses them
    throughout, so `air.execute` bodies computing on `index` are not yet importable.

## Next phase

### Acceptance checklist for each layer

Every layer added -- async dependencies, DMA and memory, channels, `herd`/`segment`/`launch`,
`!air.token` lists -- answers the same six questions. Each answer is a theorem, a bounded
exhaustive check, or a counterexample, and is stated as one of these. Lean answers only the
questions put to it, so this list is what makes the coverage systematic.

| # | Question | Shape of the answer |
| --- | --- | --- |
| C1 | **Well-formedness.** Does every program AIR's verifier accepts have a defined meaning? | Theorem `verify ok → extract ok`, or a counterexample (a verifier gap) |
| C2 | **Progress.** Does every well-formed program have a complete execution? When can it deadlock? | Theorem `∃ trace to all-done`, or a characterisation of deadlocks |
| C3 | **Determinism.** Under which conditions do all schedules compute the same result? | Theorem `race-free → same outcome`, plus exact race detection |
| C4 | **Constraint consistency.** Can the constraints (dependency, affinity, concurrency, resources) contradict each other? | Theorem `well-formed → constraints satisfiable`, or a contradictory program |
| C5 | **Pass correctness.** Does each pass preserve every behaviour? | A refinement or trace-equivalence theorem for the model, plus translation validation of the C++ output |
| C6 | **Expressiveness.** Relative to a stated target model (for example AIE DMA/locks/streams, or a GPU grid), what can the layer not express? | A theorem of completeness relative to the target, or a behaviour shown to be unrepresentable |

How each question is checked:
- **Proof** gives a guarantee for every program.
- **Bounded exhaustive checking** (`Test/Air/bounded/`) gives one for every program up to a stated
  size. Most semantic bugs show up at small sizes (the small-scope hypothesis).
- **Translation validation and differential runs** (the interpreter against `air-opt` and against
  hardware) are the only ways to compare the model with AIR's real behaviour. Lean cannot do that.

Status of the async-dependency layer:

| # | Status |
| --- | --- |
| C1 | **Counterexample found:** AIR accepts a mismatched `air.execute` terminator (D8, confirmed bug). No theorem yet: `extract` is not proven. |
| C2 | **Proven** (`progress`): dependencies alone never deadlock. Also checked by the bounded run. Becomes a real question with channels, whose `get` can block. |
| C3 | **Proven at event granularity** (`deterministic`): race-free programs with framed effects end in the same memory under every schedule; `raceFreeB_iff` decides race-freedom. Bounded check (values): race warning ⇔ some schedule differs. Interleavings *inside* bodies (D7) not yet proven. |
| C4 | Trivial while only dependency lists exist (a DAG is always satisfiable). Becomes real with `concurrency` tokens (D9), which can contradict a dependency path. |
| C5 | **Proven** for the model's reduction (`steps_reduce_iff`). `air-dependency-canonicalize`, checked exhaustively (`Test/Air/bounded/check.py`): **passes** on all 78,183 graphs of 1–5 events whose `air.execute` bodies have 0 or 1 ops. **Fails** when a body has 2 or more ops: 1,314 of the 2,448 programs of up to 4 events with 2-op bodies. The pass drops every outgoing edge of such an execute, which can make a race-free program racy (974 of 5,330 race-free programs in `--data` mode). Root cause located; see Findings. Reproducer: `Test/Air/bounded/repro_canonicalize_drops_edge.mlir.in`. |
| C6 | Not started; needs a target model. |

Status of the memory and DMA layer (layer 2, function scope):

| # | Status |
| --- | --- |
| C1 | **Counterexamples found:** AIR accepts a DMA whose src and dst element counts differ (AIR-008); and a subview folded into a DMA addresses other elements (AIR-009, proven: `foldAsAIR_wrong`). `air-veir races` reports both kinds statically. |
| C2 | Unchanged: DMAs are events, and `progress` covers them. |
| C3 | **Proven** for framed effects (`deterministic`). Checked for the implementation on every race-free program of `check_dependency.py`: 166 of 196 and 1,822 of 2,744, each with exactly one outcome. |
| C4 | Not applicable yet (no affinity/concurrency). |
| C5 | Canonicalize preserves race-freedom (`raceFree_reduce_iff`). `air-dependency` does **not** establish it (AIR-007, exhaustively above). |
| C6 | Not started. |

Status of the loop layer (layer 3, host-level `scf.for` / `scf.parallel`, by instantiation):

| # | Status |
| --- | --- |
| C1 | Bounds must be known; otherwise refused with a diagnostic. |
| C2 | `progress` applies to the instantiated graph. |
| C3 | `deterministic` applies to the instances. Example: a ping-pong loop (252 schedules) computes one outcome. |
| C5 | `check_loops.py`: across 976 loop programs, `air-dependency` leaves 324 racy (all races within one iteration, from offsets on `%i`: AIR-007), and `air-dependency-canonicalize` never changes the instantiated ordering. `air-veir reduce` refuses loops; `check` compares instantiated graphs. |

Status of the channel layer (layer 4):

| # | Status |
| --- | --- |
| C1 | Errors reported statically: D33 order races, a put no get drains, a get no put feeds, a broadcast with too few gets. |
| C2 | **Real now:** an async put and get have no buffer (D30), so a program can deadlock. Each verdict is a certificate checked by a proven-sound checker (`scheduleB_sound`, `no_schedule_of_stuckB`). |
| C3 | Races include the transfers themselves, as virtual nodes (D36(b)), and the order within a transfer (D36(a)). `check_channels.py`: 0 of 200 inputs racy. |
| C5 | `check_channels.py`: `air-dependency` makes 93 of 200 deadlock-free programs deadlock; `air-dependency-canonicalize` keeps all 93. The edge it adds between a put and the get it feeds is the cause (AIR-011). With only the edges D33 requires, 48 of the 93 are correct; the other 45 race, and need a buffered (sync) end. |
| C6 | Not started. |

Status of the hierarchy layer (layer 5):

| # | Status |
| --- | --- |
| C1 | `air-verify-hierarchy-locality`, AIR's own race check for herd operands, accepts overlapping per-tile slices (AIR-013, on its positive tests). |
| C2 | Certified as in layer 4. Under D38 (i), `air-dependency`'s drain rule deadlocks (AIR-012). |
| C3 | Instances are concurrent, so races between tiles are found (`hierarchy.mlir`). |
| C5 | `sweep_dependency.py` analyses each chunk before and after `air-dependency` (D45 makes the input analysable). Over 232 AIR test files (all of `AIRDependency/`, and every test with a herd and channels): 100 functions analysed; 50 ok, 22 problems already in the input, 25 fragments (a sync put nothing gets), and **3 introduced by `air-dependency`**: AIR-012 (drain edge deadlock) and AIR-014 (channel FIFO order lost across a loop, twice). With branches supported, 5 more: AIR-020 (ops after `scf.if`/`affine.if` do not wait for accesses inside it, 4 tests) and `shared_l1_placement` (likely AIR-012). Inputs already async (tests of other passes) are analysed as written. Output: `~/air-issues/notes/sweep_2026_11_14.out`. |
| C6 | Deferred until the whole dialect is covered (below). |

### C6: the target model (started 2026-11-14)

Target: the AIE2P DMA buffer descriptors and locks, at the level `air-to-aie` and `airrt-to-npu`
produce. Hardware decisions T1-T5 and what the model covers are in
[`AIE_SEMANTICS.md`](AIE_SEMANTICS.md).

- `air-veir aie <file>` (phase 1) explores a design: every interleaving, deadlocks with a run
  reaching them, and the distinct outcomes of host memory.
- `air-veir outcome <file>` prints an AIR program's host memory after one complete run. For a
  race-free program, this is its only outcome (C3).
- `Test/Air/bounded/check_lowering.py` (phase 2) compiles small data-movement programs with
  `aircc`. It then requires the design to reach exactly the program's one outcome, without
  deadlocking.

### Order of work (decided 2026-11-14)

1. Finish the AIR dialect layer by layer: layer 5 is `air.launch` / `air.segment` / `air.herd`;
   after it come the remaining ops (`!air.token` lists if they get implemented, `scf.if`, and the
   rest).
2. **Then** C6 for every layer at once: choose a target model (AIE DMA BDs and locks, streams)
   and find what AIR cannot express, or expresses only with loss.

### What each AIR concept needs

What each AIR concept needs before it can be given a meaning:

| Part | Semantics to add |
| --- | --- |
| Memory | allocation identity; aliasing and views; shape, stride and offset; memory space as accessibility (`memref<…, 1>` L2, `2` L1); lifetimes bounded by `memref.dealloc` events |
| DMA | `dma_memcpy_nd` as an event that reads and writes access-pattern regions between start and finish; a buffer must not be touched by an unordered event while a DMA on it is outstanding (the obligation the token edges discharge) |
| Channel (done, layer 4) | `put`/`get` matching per channel *and index*; FIFO order; capacity and flow control (a `put` may block); completion; buffer reuse after the token. A message is data, and its arrival is not an async-token completion. Check `air.channel` semantics against `AIRToAIE` before treating a channel as a FIFO of values. |
| Spatial scopes | each `herd`/`segment`/`launch` instance as its own events, with private (L1) and shared (L2) allocations. `launch` instances may be parallel or sequential, `segment` instances are co-resident, `herd` tiles are concurrent. Keep the logical mapping separate from physical placement. |
| Resources | to model `air.segment` co-residency and progress, which matter once channels can block |

Concrete next tasks:
1. ~~Prove that `Program.reducedGraph` lies between `g.reduce` and `g`.~~ Done
   (`Program.steps_reducedGraph_iff`). `air-veir reduce` keeps its run-time `sameReach` only as a
   check that `applyReduction` wrote what `reducedGraph` says.
2. Prove `extract` produces forward graphs. Or keep the run-time `forwardB`, which `sameReach_sound`
   already covers.
3. ~~Model `scf.for` with loop-carried tokens~~ Done for host-level loops with known bounds (layer 3). Model `scf.for` with loop-carried tokens by unrolling bounded loops, a common
   `air-dependency-canonicalize` input.
4. ~~Add DMA events~~ Done (layer 2). Add DMA events with region-level read/write effects, and prove token edges cover every
   conflicting pair. This is where the checker becomes a data-race checker for AIR passes.
5. ~~Accept untyped integer literals~~ Done for list elements (VEIR-002). Accept untyped integer literals as `i64`, as MLIR does; it unlocks `air.channel` import.
