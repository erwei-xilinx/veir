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

## What is and is not established

Each claim is listed at its own level; they do not imply one another.

| Claim | Status |
| --- | --- |
| AIR text can be imported | Yes. 140 of 473 AIR test modules round-trip identically, 0 differ. 332 are refused for VeIR limitations outside this work, and 1 hits a VeIR `llvm` bug (see [Results](#results)). |
| The supported subset can be interpreted | Yes, by `Program.finishEvent` and `air-veir run`. |
| The theorems pass Lean's kernel | Yes. No `sorry`, no `native_decide`, no new axioms (see [Theorems](#theorems)). |
| The `air-dependency-canonicalize` output passes the checker | Yes, on every AIR test file in the subset (4 of 4), and on the fixtures. Only for those instances. |
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
uv run lit Test/Air -v            # the AIR lit tests (7)
uv run lit Test/ -q               # all of VeIR's lit tests
AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh            # checks that need air-opt
AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh --sweep /path/to/mlir-air/mlir/test
```

`air-veir --help` describes the tool:

```bash
air-opt in.mlir --mlir-print-op-generic --mlir-print-local-scope -o in.generic.mlir
.lake/build/bin/air-veir graph  in.generic.mlir   # events, edges kept by the reduction, unordered reads
.lake/build/bin/air-veir run    in.generic.mlir   # values, and agreement across all allowed orders
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
| Proofs | — | — | `Veir/Air/DepGraph.lean`, `Veir/Air/Events.lean` |
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
| `air.launch`, `air.segment`, `air.herd`, `air.dma_memcpy_nd`, `air.channel.*`, `memref.*`, `scf.*` | `--allow-unregistered-dialect`; round-trips | none | **refused with a diagnostic** | — |
| `air.channel` declarations | **refused by VeIR's parser:** `size = [1]` is an untyped integer, and VeIR requires `1 : i64` | — | — | — |

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
- memory: allocation, aliasing, views, effects of `memref.*`;
- DMA and channels;
- loops and loop-carried tokens;
- spatial scopes (`launch`/`segment`/`herd`) and their instances;
- resources and timing;
- host program order, beyond blocking `air.wait_all`;
- interleaving *within* an event body. Effects happen at the start and finish steps, so a body
  that interleaves with another at a finer grain needs those steps modelled as separate events.

## Theorems

All are in `Veir/Air/DepGraph.lean` and `Veir/Air/Events.lean`, checked by Lean's kernel, with no
`sorry`. `UnitTest/Air.lean` pins `#print axioms` for each:
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
| `cyclic_simultaneous_drop_unsound` (UnitTest) | on a cycle, deciding edges independently and dropping them together loses reachability | — |

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
- `uv run lit Test/Air`: 7 of 7 pass.
- `uv run lit Test/`: 1593 passed, 8 unsupported, 2 expectedly failed, 0 failed.

**AIR integration** (`air-integration.sh`, 2026-11-13):
- The three fixtures round-trip identically after `air-opt` normalisation, including `id`
  attributes, `operandSegmentSizes` and `INT64_MIN` static offsets.
- For the two fixtures in the subset, both `air-veir reduce` and `air-dependency-canonicalize`
  pass `check`.
- `prune_redundant_edges.mlir` is refused at its `air.launch`.

**Sweep of AIR's `mlir/test`** (631 files):
- 158 skipped: expected-error tests, split-input files, or not accepted by `air-opt`.
- Of the remaining 473:
  - 140 round-trip identically and 0 differ;
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
  - VeIR rejects an integer literal without a type in an attribute (`size = [1]`), which MLIR
    reads as `i64`. No VeIR test asserts this, so it is a conformance gap rather than a stated
    design choice. It blocks every `air.channel` declaration. (An earlier version of this file
    called it deliberate; the tests cited then concern malformed floats.)
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
| C3 | Planned theorem: race-free (D4) implies the same outcome. Bounded check: race warning ⇔ some schedule differs. |
| C4 | Trivial while only dependency lists exist (a DAG is always satisfiable). Becomes real with `concurrency` tokens (D9), which can contradict a dependency path. |
| C5 | **Proven** for the model's reduction (`steps_reduce_iff`). `air-dependency-canonicalize`, checked exhaustively (`Test/Air/bounded/check.py`): **passes** on all 78,183 graphs of 1–5 events whose `air.execute` bodies have 0 or 1 ops. **Fails** when a body has 2 or more ops: 1,314 of the 2,448 programs of up to 4 events with 2-op bodies. The pass drops every outgoing edge of such an execute, which can make a race-free program racy (974 of 5,330 race-free programs in `--data` mode). Root cause located; see Findings. Reproducer: `Test/Air/bounded/repro_canonicalize_drops_edge.mlir.in`. |
| C6 | Not started; needs a target model. |

### What each AIR concept needs

What each AIR concept needs before it can be given a meaning:

| Part | Semantics to add |
| --- | --- |
| Memory | allocation identity; aliasing and views; shape, stride and offset; memory space as accessibility (`memref<…, 1>` L2, `2` L1); lifetimes bounded by `memref.dealloc` events |
| DMA | `dma_memcpy_nd` as an event that reads and writes access-pattern regions between start and finish; a buffer must not be touched by an unordered event while a DMA on it is outstanding (the obligation the token edges discharge) |
| Channel | `put`/`get` matching per channel *and index*; FIFO order; capacity and flow control (a `put` may block); completion; buffer reuse after the token. A message is data, and its arrival is not an async-token completion. Check `air.channel` semantics against `AIRToAIE` before treating a channel as a FIFO of values. |
| Spatial scopes | each `herd`/`segment`/`launch` instance as its own events, with private (L1) and shared (L2) allocations. `launch` instances may be parallel or sequential, `segment` instances are co-resident, `herd` tiles are concurrent. Keep the logical mapping separate from physical placement. |
| Resources | to model `air.segment` co-residency and progress, which matter once channels can block |

Concrete next tasks:
1. ~~Prove that `Program.reducedGraph` lies between `g.reduce` and `g`.~~ Done
   (`Program.steps_reducedGraph_iff`). `air-veir reduce` keeps its run-time `sameReach` only as a
   check that `applyReduction` wrote what `reducedGraph` says.
2. Prove `extract` produces forward graphs. Or keep the run-time `forwardB`, which `sameReach_sound`
   already covers.
3. Model `scf.for` with loop-carried tokens by unrolling bounded loops, a common
   `air-dependency-canonicalize` input.
4. Add DMA events with region-level read/write effects, and prove token edges cover every
   conflicting pair. This is where the checker becomes a data-race checker for AIR passes.
5. Accept untyped integer literals as `i64`, as MLIR does; it unlocks `air.channel` import.
