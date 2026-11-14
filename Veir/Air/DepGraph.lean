module

public import Std.Data.HashMap

namespace Veir.Air

@[expose] public section

/-! # Dependency graphs of AIR async events

An AIR async program is, for the purposes of this file, a finite set of events numbered
`0, …, n-1` together with the tokens each one waits for. The numbering is the order in which the
events appear in their block, so SSA dominance makes every dependency point backwards:
`air.execute [%t]` can only name a `%t` defined above it. `DepGraph.Forward` is that property, and
it is what makes the graph acyclic. A graph with a cycle cannot be imported (`Veir.Air.Extract`
refuses a token used before its definition) and is outside every theorem here.

`preds[v]` lists the events `v` waits for, so an edge `u → v` reads "`v` must wait for `u` to
complete". This matches the direction of the edges `air-dependency-canonicalize` builds in
`mlir/lib/Util/Dependency.cpp`, where `inverseAdjacentVertices(v)` are the operands of `v`.

## The algorithm being modelled

`DirectedAdjacencyMap::applyTransitiveReduction` (`mlir/lib/Util/DirectedAdjacencyMap.cpp`) keeps
an edge `i → nxt` unless some *other* successor `other` of `i` has `closure[other][nxt]`, and it
decides every edge against the *original* closure before removing any of them. `DepGraph.reduce`
is that loop, written over predecessor lists; `reduce` keeps `u ∈ preds[v]` unless some other
successor `o` of `u` reaches `v`.

Deciding every edge against the original closure and then removing all of them at once is only
sound because the graph is acyclic: on a cycle, two edges can each be the other's alternative
path. `reach_reduce_iff` is the statement that on a `Forward` graph it is sound.
-/

/-- An event dependency graph. `preds[v]` are the events `v` waits for. -/
structure DepGraph where
  preds : Array (List Nat)
deriving Inhabited, Repr, BEq

namespace DepGraph

/-- The number of events. -/
def size (g : DepGraph) : Nat := g.preds.size

/-- The events `v` waits for, or none if `v` is not an event. -/
def predsOf (g : DepGraph) (v : Nat) : List Nat := g.preds[v]?.getD []

/-- Every dependency of an event is an event numbered before it. -/
def Forward (g : DepGraph) : Prop := ∀ v u, u ∈ g.predsOf v → u < v

/-- `Reach g u v`: `v` cannot start before `u` completes, through any chain of dependencies.
Reflexive, as is the closure `applyTransitiveReduction` computes. -/
inductive Reach (g : DepGraph) : Nat → Nat → Prop
  | refl (u : Nat) : Reach g u u
  | step {u w v : Nat} : Reach g u w → w ∈ g.predsOf v → Reach g u v

theorem Reach.single {g : DepGraph} {u v : Nat} (h : u ∈ g.predsOf v) : Reach g u v :=
  .step (.refl u) h

theorem Reach.trans {g : DepGraph} {u w v : Nat} (h₁ : Reach g u w) (h₂ : Reach g w v) :
    Reach g u v := by
  induction h₂ with
  | refl => exact h₁
  | step _ hp ih => exact .step ih hp

/-- Reachability is monotone in the edge set. -/
theorem Reach.mono {g h : DepGraph} (sub : ∀ u v, u ∈ g.predsOf v → u ∈ h.predsOf v)
    {u v : Nat} (r : Reach g u v) : Reach h u v := by
  induction r with
  | refl => exact .refl _
  | step _ hp ih => exact .step ih (sub _ _ hp)

/-- On a forward graph, reachability only goes forwards. -/
theorem Reach.le {g : DepGraph} (hf : g.Forward) {u v : Nat} (r : Reach g u v) : u ≤ v := by
  induction r with
  | refl => exact Nat.le_refl _
  | step _ hp ih => exact Nat.le_of_lt (Nat.lt_of_le_of_lt ih (hf _ _ hp))

/-- A non-trivial path ends in an edge, whose source the path reaches. -/
theorem Reach.last {g : DepGraph} {u v : Nat} (r : Reach g u v) (hne : u ≠ v) :
    ∃ w, w ∈ g.predsOf v ∧ Reach g u w := by
  cases r with
  | refl => exact absurd rfl hne
  | step r hp => exact ⟨_, hp, r⟩

/-! ### Deciding reachability

`reachB` follows only edges that go backwards in the numbering, so it terminates by well-founded
recursion on `v` and needs no fuel or visited set. On a `Forward` graph every edge goes backwards
and `reachB` is exact (`reachB_iff`); on any graph it is sound (`reach_of_reachB`). -/

/-- Whether `v` (transitively) waits for `u`, following only edges that go backwards. -/
def reachB (g : DepGraph) (u v : Nat) : Bool :=
  u == v || (g.predsOf v).any fun w => if _ : w < v then reachB g u w else false
termination_by v

theorem reachB_eq (g : DepGraph) (u v : Nat) :
    reachB g u v =
      (u == v || (g.predsOf v).any fun w => if _ : w < v then reachB g u w else false) := by
  rw [reachB]

theorem reach_of_reachB {g : DepGraph} {u v : Nat} (h : reachB g u v = true) : Reach g u v := by
  induction v using Nat.strongRecOn with
  | ind v ih =>
    rw [reachB_eq] at h
    simp only [Bool.or_eq_true, beq_iff_eq, List.any_eq_true] at h
    rcases h with rfl | ⟨w, hw, hb⟩
    · exact .refl _
    · by_cases hlt : w < v
      · simp only [hlt, dite_true] at hb
        exact .step (ih w hlt hb) hw
      · simp [hlt] at hb

theorem reachB_of_reach {g : DepGraph} (hf : g.Forward) {u v : Nat} (r : Reach g u v) :
    reachB g u v = true := by
  induction r with
  | refl => rw [reachB_eq]; simp
  | @step w v _ hp ih =>
    rw [reachB_eq]
    simp only [Bool.or_eq_true, beq_iff_eq, List.any_eq_true]
    exact Or.inr ⟨w, hp, by simp [hf _ _ hp, ih]⟩

theorem reachB_iff {g : DepGraph} (hf : g.Forward) {u v : Nat} :
    reachB g u v = true ↔ Reach g u v :=
  ⟨reach_of_reachB, reachB_of_reach hf⟩

/-! ### The transitive reduction of `air-dependency-canonicalize` -/

/-- The events that wait for `u`. -/
def succsOf (g : DepGraph) (u : Nat) : List Nat :=
  (List.range g.size).filter fun o => decide (u ∈ g.predsOf o)

/-- `applyTransitiveReduction`'s test for the edge `u → v`: it is dropped exactly when some other
successor `o` of `u` reaches `v`. -/
def keepEdge (g : DepGraph) (u v : Nat) : Bool :=
  !((g.succsOf u).any fun o => o != v && g.reachB o v)

/-- `applyTransitiveReduction`: every edge is decided against the original graph, then all the
dropped ones are removed together. -/
def reduce (g : DepGraph) : DepGraph :=
  ⟨g.preds.mapIdx fun v ps => ps.filter fun u => g.keepEdge u v⟩

theorem predsOf_reduce (g : DepGraph) (v : Nat) :
    g.reduce.predsOf v = (g.predsOf v).filter fun u => g.keepEdge u v := by
  simp only [predsOf, reduce, Array.getElem?_mapIdx]
  cases g.preds[v]? <;> rfl

@[simp] theorem size_reduce (g : DepGraph) : g.reduce.size = g.size := by
  simp [size, reduce]

/-- The reduction only removes edges. -/
theorem reduce_sub (g : DepGraph) {u v : Nat} (h : u ∈ g.reduce.predsOf v) : u ∈ g.predsOf v := by
  rw [predsOf_reduce] at h
  exact (List.mem_filter.mp h).1

theorem Forward.reduce {g : DepGraph} (hf : g.Forward) : g.reduce.Forward :=
  fun v u h => hf v u (reduce_sub g h)

/-- Why an edge was dropped: another successor of its source already reaches its target. -/
theorem alternative_of_not_keepEdge {g : DepGraph} {u v : Nat} (h : g.keepEdge u v = false) :
    ∃ o, u ∈ g.predsOf o ∧ o ≠ v ∧ Reach g o v := by
  simp only [keepEdge, Bool.not_eq_false', List.any_eq_true, Bool.and_eq_true, bne_iff_ne,
    ne_eq] at h
  obtain ⟨o, ho, hne, hr⟩ := h
  simp only [succsOf, List.mem_filter, decide_eq_true_eq] at ho
  exact ⟨o, ho.2, hne, reach_of_reachB hr⟩

/-- A path whose every edge is spanned by `r` is a path of `r`. -/
private theorem reach_of_edges {g r : DepGraph} (hf : g.Forward) {a b : Nat} (p : Reach g a b)
    (edges : ∀ x y, x ∈ g.predsOf y → a ≤ x → y ≤ b → Reach r x y) : Reach r a b := by
  induction p with
  | refl => exact .refl _
  | @step w v pw hp ih =>
    have hwv : w < v := hf _ _ hp
    have haw : a ≤ w := pw.le hf
    have left := ih fun x y he hx hy => edges x y he hx (Nat.le_trans hy (Nat.le_of_lt hwv))
    exact left.trans (edges w v hp haw (Nat.le_refl _))

/-- Every edge the reduction drops is still a path of the reduced graph. -/
theorem reach_reduce_of_edge {g : DepGraph} (hf : g.Forward) :
    ∀ n u v, u ∈ g.predsOf v → v - u ≤ n → Reach g.reduce u v := by
  intro n
  induction n using Nat.strongRecOn with
  | ind n ih =>
    intro u v he hspan
    cases hk : g.keepEdge u v with
    | true =>
      apply Reach.single
      rw [predsOf_reduce]
      exact List.mem_filter.mpr ⟨he, hk⟩
    | false =>
      obtain ⟨o, huo, hne, hov⟩ := alternative_of_not_keepEdge hk
      have huo' : u < o := hf _ _ huo
      have hov' : o < v := Nat.lt_of_le_of_ne (hov.le hf) hne
      have huv : u < v := Nat.lt_trans huo' hov'
      -- `u → o` is a shorter edge, and so is every edge on the path `o ⇝ v`.
      have first : Reach g.reduce u o :=
        ih (o - u) (by omega) u o huo (Nat.le_refl _)
      have rest : Reach g.reduce o v := by
        apply reach_of_edges hf hov
        intro x y hxy hx hy
        have hxy' : x < y := hf _ _ hxy
        exact ih (y - x) (by omega) x y hxy (Nat.le_refl _)
      exact first.trans rest

/-- **The reduction preserves reachability**, on any graph with a topological numbering. -/
theorem reach_reduce_iff {g : DepGraph} (hf : g.Forward) {u v : Nat} :
    Reach g.reduce u v ↔ Reach g u v := by
  constructor
  · exact Reach.mono fun _ _ => reduce_sub g
  · intro r
    induction r with
    | refl => exact .refl _
    | @step w v _ hp ih =>
      exact ih.trans (reach_reduce_of_edge hf _ w v hp (Nat.le_refl _))

/-- Any graph between the reduction and the original has the original's reachability. This is the
form the AIR rewrite needs: it may keep an edge the reduction would drop (an implicit edge from a
blocking `air.wait_all` is not an operand and cannot be removed), but it never adds one. -/
theorem reach_between_iff {g h : DepGraph} (hf : g.Forward)
    (lower : ∀ u v, u ∈ g.reduce.predsOf v → u ∈ h.predsOf v)
    (upper : ∀ u v, u ∈ h.predsOf v → u ∈ g.predsOf v) {u v : Nat} :
    Reach h u v ↔ Reach g u v :=
  ⟨Reach.mono upper, fun r => Reach.mono lower ((reach_reduce_iff hf).mpr r)⟩

/-! ### An executable checker

`sameReach g h` decides whether two forward graphs on the same events order them the same way. It is
how a rewrite this file did not perform -- `air-dependency-canonicalize`'s own output, say -- is
checked: `sameReach_sound` turns a `true` into the statement that the two graphs are equivalent.
-/

theorem mem_predsOf_lt {g : DepGraph} {u v : Nat} (h : u ∈ g.predsOf v) : v < g.size := by
  if hv : v < g.size then exact hv
  else simp [predsOf, Array.getElem?_eq_none (Nat.le_of_not_lt hv)] at h

/-- Whether every event of a graph waits only for earlier events. -/
def forwardB (g : DepGraph) : Bool :=
  (List.range g.size).all fun v => (g.predsOf v).all fun u => decide (u < v)

theorem forward_of_forwardB {g : DepGraph} (h : g.forwardB = true) : g.Forward := by
  intro v u hu
  have hv : v < g.size := mem_predsOf_lt hu
  simp only [forwardB, List.all_eq_true, List.mem_range, decide_eq_true_eq] at h
  exact h v hv u hu

/-- Whether two graphs on the same events agree on reachability. Only edges are compared against
the other graph's closure: that suffices, by `sameReach_sound`. -/
def sameReach (g h : DepGraph) : Bool :=
  g.size == h.size && g.forwardB && h.forwardB &&
  (List.range g.size).all fun v =>
    (g.predsOf v).all (fun u => h.reachB u v) && (h.predsOf v).all (fun u => g.reachB u v)

/-- An edge of `g` that `h` reaches makes every `g`-path an `h`-path. -/
private theorem reach_of_edges_reach {g h : DepGraph}
    (edges : ∀ u v, u ∈ g.predsOf v → Reach h u v) {u v : Nat} (r : Reach g u v) : Reach h u v := by
  induction r with
  | refl => exact .refl _
  | step _ hp ih => exact ih.trans (edges _ _ hp)

/-- **Checker soundness.** If `sameReach g h` then both graphs are forward, have the same events,
and order them identically. -/
theorem sameReach_sound {g h : DepGraph} (hc : sameReach g h = true) :
    g.size = h.size ∧ g.Forward ∧ h.Forward ∧ ∀ u v, Reach g u v ↔ Reach h u v := by
  simp only [sameReach, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, List.mem_range] at hc
  obtain ⟨⟨⟨hsz, hfg⟩, hfh⟩, hall⟩ := hc
  have fg := forward_of_forwardB hfg
  have fh := forward_of_forwardB hfh
  refine ⟨hsz, fg, fh, fun u v => ⟨?_, ?_⟩⟩
  · apply reach_of_edges_reach
    intro u v hp
    exact reach_of_reachB ((hall v (mem_predsOf_lt hp)).1 u hp)
  · apply reach_of_edges_reach
    intro u v hp
    have hv : v < g.size := hsz ▸ mem_predsOf_lt hp
    exact reach_of_reachB ((hall v hv).2 u hp)

/-! ### Reachability in polynomial time

`reachB` searches without remembering what it visited, which is exponential on graphs with many
diamonds (hierarchy ops and loop-carried tokens build them). `reachRows` computes, once and in
numbering order, the bit set of the events reaching each event; `reachFast_eq` proves it answers
as `reachB` does. Compiled code runs the fast versions of `sameReach` and `races` (`@[csimp]`);
the theorems are stated, and proven, about the originals. -/

/-- The bit set of every `u` with `reachB g u v`, given the rows of every `w < v`. -/
def rowOf (g : DepGraph) (t : Array Nat) (v : Nat) : Nat :=
  (g.predsOf v).foldl (fun acc w => if w < v then acc ||| t.getD w 0 else acc) (2 ^ v)

def reachStep (g : DepGraph) (t : Array Nat) (v : Nat) : Array Nat := t.push (g.rowOf t v)

/-- Row `v` is the bit set of the events that reach `v`, built once, in numbering order. -/
def reachRows (g : DepGraph) : Array Nat :=
  (List.range g.size).foldl g.reachStep #[]

/-- `reachB` through the rows; the same answer (`reachFast_eq`), in polynomial time. -/
def reachFast (g : DepGraph) (rows : Array Nat) (u v : Nat) : Bool :=
  if v < rows.size then (rows.getD v 0).testBit u else g.reachB u v

theorem testBit_foldl_or (t : Array Nat) (v u : Nat) (l : List Nat) (acc : Nat) :
    (l.foldl (fun acc w => if w < v then acc ||| t.getD w 0 else acc) acc).testBit u =
      (acc.testBit u || l.any fun w => if w < v then (t.getD w 0).testBit u else false) := by
  induction l generalizing acc with
  | nil => simp
  | cons w l ih =>
    simp only [List.foldl_cons, List.any_cons, ih]
    split <;> simp [Nat.testBit_or, Bool.or_assoc]

theorem testBit_rowOf {g : DepGraph} {t : Array Nat} {v : Nat}
    (ht : ∀ w < v, ∀ u, (t.getD w 0).testBit u = g.reachB u w) (u : Nat) :
    (g.rowOf t v).testBit u = g.reachB u v := by
  rw [rowOf, testBit_foldl_or, reachB_eq, Nat.testBit_two_pow]
  congr 1
  · by_cases h : u = v
    · simp [h]
    · simp [h, Ne.symm h]
  · congr 1
    funext a
    by_cases ha : a < v
    · simp only [ha, ↓reduceIte, ↓reduceDIte]
      exact ht a ha u
    · simp only [ha, ↓reduceIte, ↓reduceDIte]

theorem getD_push_lt {T : Array Nat} {x w : Nat} (h : w < T.size) : (T.push x).getD w 0 = T.getD w 0 := by
  simp [Array.getD_eq_getD_getElem?, Array.getElem?_push, Nat.ne_of_lt h]

theorem getD_push_size {T : Array Nat} {x : Nat} : (T.push x).getD T.size 0 = x := by
  simp [Array.getD_eq_getD_getElem?]

theorem reachRows_spec (g : DepGraph) (k : Nat) :
    ((List.range k).foldl g.reachStep #[]).size = k ∧
    ∀ w < k, ∀ u, (((List.range k).foldl g.reachStep #[]).getD w 0).testBit u = g.reachB u w := by
  induction k with
  | zero => simp
  | succ k ih =>
    simp only [List.range_succ, List.foldl_append, List.foldl_cons, List.foldl_nil, reachStep]
    generalize (List.range k).foldl g.reachStep #[] = T at ih ⊢
    obtain ⟨hs, hr⟩ := ih
    refine ⟨by simp [hs], fun w hw u => ?_⟩
    by_cases hwk : w < k
    · rw [getD_push_lt (by omega)]
      exact hr w hwk u
    · obtain rfl : w = k := by omega
      rw [← hs, getD_push_size, hs]
      exact testBit_rowOf (fun w' hw' => hr w' (by omega)) u

/-- **The rows answer exactly what `reachB` answers.** -/
theorem reachFast_eq (g : DepGraph) (u v : Nat) : g.reachFast g.reachRows u v = g.reachB u v := by
  have ⟨hs, hr⟩ := reachRows_spec g g.size
  by_cases h : v < g.reachRows.size
  · simp only [reachFast, h, ↓reduceIte]
    exact hr v (by simpa [reachRows, hs] using h) u
  · simp only [reachFast, h, ↓reduceIte]

/-- `sameReach`, with each graph's rows computed once. -/
def sameReachFast (g h : DepGraph) : Bool :=
  let rg := g.reachRows
  let rh := h.reachRows
  g.size == h.size && g.forwardB && h.forwardB &&
  (List.range g.size).all fun v =>
    (g.predsOf v).all (fun u => h.reachFast rh u v) && (h.predsOf v).all (fun u => g.reachFast rg u v)

/-- Compiled code runs `sameReachFast`; proofs keep `sameReach`. -/
@[csimp] theorem sameReach_eq_sameReachFast : @sameReach = @sameReachFast := by
  funext g h
  simp [sameReach, sameReachFast, reachFast_eq]

end DepGraph

end

end Veir.Air
