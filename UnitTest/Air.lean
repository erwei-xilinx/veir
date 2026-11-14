import Veir.Air.Extract
import Veir.Air.Determinism
import Veir.Air.Pattern
import Veir.Air.Schedule

/-! Tests for the AIR event-graph model.

The command-line behaviour -- import, run, reduce, check -- is tested in `Test/Air`. This file
checks the graph functions on small graphs, shows why the reduction is restricted to forward
graphs, and pins down the axioms the main theorems rest on.
-/

open Veir.Air
open Veir.Air.DepGraph

/-- `A → B → C` and `A → C`. -/
private def chain : DepGraph := ⟨#[[], [0], [0, 1]]⟩

/-- Only `A → C`; `B` is independent. -/
private def requiredOnly : DepGraph := ⟨#[[], [], [0]]⟩

/-- `requiredOnly` without its edge. -/
private def none3 : DepGraph := ⟨#[[], [], []]⟩

-- The redundant edge goes and the necessary ones stay.
#guard chain.reduce == ⟨#[[], [0], [1]]⟩
#guard sameReach chain chain.reduce
-- The only edge of `requiredOnly` is necessary; dropping it is caught.
#guard requiredOnly.reduce == requiredOnly
#guard !sameReach requiredOnly none3
-- Independent events gain no edge.
#guard none3.reduce == none3
-- Graphs on different events are never equivalent, nor is a graph with a backward edge.
#guard !sameReach chain ⟨#[[], [0]]⟩
#guard !(⟨#[[1], [0]]⟩ : DepGraph).forwardB
#guard !sameReach ⟨#[[1], [0]]⟩ ⟨#[[1], [0]]⟩
-- The finishing orders the graphs allow.
#guard chain.orders.length == 1
#guard requiredOnly.orders.length == 3
#guard none3.orders.length == 6
#guard requiredOnly.allowsOrder [1, 0, 2] && !requiredOnly.allowsOrder [2, 0, 1]

/-! ### Why acyclicity is needed

On a cycle, two edges can each be redundant because of the other: `A → C` is implied by
`A → B → C`, and `B → C` by `B → A → C`. Deciding both against the original graph and removing
both, as `applyTransitiveReduction` does, disconnects `C`. `reach_reduce_iff` avoids this by
requiring a `Forward` graph, which AIR's SSA dominance provides. -/

/-- `A` and `B` wait for each other, and `C` waits for both. -/
private def cyclic : DepGraph := ⟨#[[1], [0], [0, 1]]⟩

/-- `cyclic` with both of `C`'s edges removed. -/
private def cyclicDropped : DepGraph := ⟨#[[1], [0], []]⟩

theorem cyclic_edges_each_redundant :
    Reach cyclic 0 1 ∧ 1 ∈ cyclic.predsOf 2 ∧ Reach cyclic 1 0 ∧ 0 ∈ cyclic.predsOf 2 := by
  refine ⟨.single ?_, ?_, .single ?_, ?_⟩ <;> simp [cyclic, predsOf]

theorem cyclic_simultaneous_drop_unsound :
    Reach cyclic 0 2 ∧ ¬ Reach cyclicDropped 0 2 := by
  refine ⟨.single (by simp [cyclic, predsOf]), fun r => ?_⟩
  cases r with
  | step _ hp => simp [cyclicDropped, predsOf] at hp

/-! ### Axioms

The theorems below use only Lean's standard axioms: `propext` and `Quot.sound`, and for the AIR
instance also `Classical.choice`, which the IR and runtime-value types in its statement bring in.
Nothing depends on `sorryAx`, on `Lean.ofReduceBool` (no `native_decide`), or on an axiom of this
development. -/

/--
info: 'Veir.Air.DepGraph.reach_reduce_iff' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms DepGraph.reach_reduce_iff

/--
info: 'Veir.Air.DepGraph.sameReach_sound' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms DepGraph.sameReach_sound

/--
info: 'Veir.Air.steps_reduce_iff' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms steps_reduce_iff

/--
info: 'Veir.Air.steps_between_iff' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms steps_between_iff

/--
info: 'Veir.Air.steps_of_sameReach' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms steps_of_sameReach

/--
info: 'Veir.Air.Program.steps_reduce_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Program.steps_reduce_iff

/--
info: 'Veir.Air.progress' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms progress

/--
info: 'Veir.Air.Program.steps_reducedGraph_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms Program.steps_reducedGraph_iff

/-! ### Layer 2: access patterns, races, determinism -/

open Veir.Air in
section
-- D14: `offsets [4] sizes [4] strides [2]` touches 8, 10, 12, 14 (offset in units of the stride).
#guard positions [⟨4, 4, 2⟩] == [8, 10, 12, 14]
-- A stride of 0 repeats (D15).
#guard positions [⟨0, 3, 0⟩, ⟨0, 2, 1⟩] == [0, 1, 0, 1, 0, 1]
-- 2-D: rows 1 and 3 of a 4x8 buffer, columns 2..5, written the AIR way.
#guard positions [⟨0, 2, 16⟩, ⟨10, 4, 1⟩] == [10, 11, 12, 13, 26, 27, 28, 29]
#guard positions (foldFixed 0 [⟨1, 2, 2, 8⟩, ⟨2, 4, 1, 1⟩]) == subviewFrom 0 [⟨1, 2, 2, 8⟩, ⟨2, 4, 1, 1⟩]

/-- AIR-007's shape: event 0 writes rows 1-2 of buffer 0 (a 4x8 buffer), event 1 reads row 2. -/
private def writeRows12 : Access := ⟨0, .write, positions [⟨1, 2, 8⟩, ⟨0, 8, 1⟩]⟩
private def readRow2 : Access := ⟨0, .read, positions [⟨2, 1, 8⟩, ⟨0, 8, 1⟩]⟩
private def readRow0 : Access := ⟨0, .read, positions [⟨0, 1, 8⟩, ⟨0, 8, 1⟩]⟩
private def fp7 (r : Access) : Footprint := fun v => if v = 0 then [writeRows12] else if v = 1 then [r] else []

-- Without an edge, the overlapping read is a race (what air-dependency produces for AIR-007) ...
#guard races ⟨#[[], []]⟩ (fp7 readRow2) == [(0, 1)]
-- ... with the edge it is not ...
#guard raceFreeB ⟨#[[], [0]]⟩ (fp7 readRow2)
-- ... and a read of a row the write does not touch needs no edge.
#guard raceFreeB ⟨#[[], []]⟩ (fp7 readRow0)
-- Two reads never race.
#guard raceFreeB ⟨#[[], []]⟩ (fun v => if v = 0 then [readRow0] else [readRow2])
end

/--
info: 'Veir.Air.deterministic' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms deterministic

/--
info: 'Veir.Air.raceFreeB_iff' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms raceFreeB_iff

/--
info: 'Veir.Air.raceFree_reduce_iff' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms raceFree_reduce_iff

/--
info: 'Veir.Air.positions_foldFixed' depends on axioms: [propext, Classical.choice, Quot.sound]
-/
#guard_msgs in
#print axioms positions_foldFixed

/--
info: 'Veir.Air.foldAsAIR_wrong' does not depend on any axioms
-/
#guard_msgs in
#print axioms foldAsAIR_wrong

-- Layer 4: a schedule certificate and a deadlock certificate, each checked.
#guard scheduleB ⟨#[[], [0], [0, 1]]⟩ [0, 1, 2]
#guard !scheduleB ⟨#[[], [0], [0, 1]]⟩ [1, 0, 2]
-- A rendezvous with a token edge from the put to the get: nodes are start/finish of the put
-- (0, 1) and of the get (2, 3). F(P) waits for S(G), S(G) waits for F(P): stuck.
#guard stuckB ⟨#[[], [0, 2], [1], [2]]⟩ [1, 2]
#guard !stuckB ⟨#[[], [0, 2], [1], [2]]⟩ [0]

/--
info: 'Veir.Air.DepGraph.scheduleB_sound' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms scheduleB_sound

/--
info: 'Veir.Air.DepGraph.no_schedule_of_stuckB' depends on axioms: [propext, Quot.sound]
-/
#guard_msgs in
#print axioms no_schedule_of_stuckB
