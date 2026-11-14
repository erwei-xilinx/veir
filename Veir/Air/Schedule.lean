module

public import Veir.Air.Determinism

namespace Veir.Air

@[expose] public section

/-! # Schedules and deadlocks of AND-graphs

With channels (layer 4), an event cannot be treated as one atomic step. An async put and the get
it feeds have no buffer between them (`SEMANTICS.md` D30), so neither can finish before the other
has started. So each event becomes two nodes, its start and its finish, and every constraint
becomes an edge between nodes:
- token dependencies;
- program order behind blocking ops;
- a get waiting for its data;
- a rendezvous.

A node may fire once all its predecessors have fired: an AND-graph, represented as a `DepGraph`
that need not be forward.

The program can run to completion iff the graph has a complete firing order (a *schedule*). It
deadlocks iff it has none, and then some nonempty set of nodes is *stuck*: every node in it waits
for another node in it. Both answers come with a certificate, checked by a checker proven sound
here:
- `scheduleB` checks a schedule (`scheduleB_sound`);
- `stuckB` checks a stuck set (`no_schedule_of_stuckB`).

`kahn` finds one or the other.
-/

namespace DepGraph

/-- A complete firing order: every node once, each after its predecessors. -/
def Schedule (g : DepGraph) (l : List Nat) : Prop :=
  Valid g [] l ∧ ∀ v, v < g.size → v ∈ l

/-- Checks that `l` fires each node after its predecessors, never twice, and fires them all. -/
def scheduleB (g : DepGraph) (l : List Nat) : Bool :=
  go [] l && (List.range g.size).all l.contains
where
  go (done : List Nat) : List Nat → Bool
    | [] => true
    | v :: rest =>
      decide (v < g.size) && !done.contains v && (g.predsOf v).all done.contains && go (v :: done) rest

theorem scheduleB.go_sound {g : DepGraph} {done l : List Nat} (h : scheduleB.go g done l = true) :
    Valid g done l := by
  induction l generalizing done with
  | nil => exact .nil _
  | cons v rest ih =>
    simp only [scheduleB.go, Bool.and_eq_true, decide_eq_true_eq, Bool.not_eq_true',
      List.all_eq_true, List.contains_iff_mem] at h
    obtain ⟨⟨⟨hlt, hnd⟩, hp⟩, hrest⟩ := h
    refine .cons hlt (by simpa using hnd) hp (ih hrest)

/-- **A checked schedule is a schedule.** -/
theorem scheduleB_sound {g : DepGraph} {l : List Nat} (h : scheduleB g l = true) : Schedule g l := by
  simp only [scheduleB, Bool.and_eq_true, List.all_eq_true, List.mem_range,
    List.contains_iff_mem] at h
  exact ⟨scheduleB.go_sound h.1, h.2⟩

/-- A nonempty set of nodes each waiting for another node of the set. -/
def Stuck (g : DepGraph) (s : List Nat) : Prop :=
  s ≠ [] ∧ ∀ v ∈ s, ∃ u ∈ g.predsOf v, u ∈ s

def stuckB (g : DepGraph) (s : List Nat) : Bool :=
  !s.isEmpty && s.all fun v => (g.predsOf v).any s.contains

theorem stuck_of_stuckB {g : DepGraph} {s : List Nat} (h : stuckB g s = true) : Stuck g s := by
  simp only [stuckB, Bool.and_eq_true, Bool.not_eq_true', List.isEmpty_eq_false_iff,
    List.all_eq_true, List.any_eq_true, List.contains_iff_mem] at h
  exact ⟨h.1, h.2⟩

/-- No node of a stuck set ever fires, from a state where none of them has. -/
theorem Stuck.never_fires {g : DepGraph} {s : List Nat} (hs : Stuck g s) {done l : List Nat}
    (hv : Valid g done l) (hd : ∀ x ∈ s, x ∉ done) : ∀ x ∈ s, x ∉ l := by
  induction hv with
  | nil => simp
  | @cons done v l _ _ hp _ ih =>
    have hvs : v ∉ s := fun hvs => by
      obtain ⟨u, hu, hus⟩ := hs.2 v hvs
      exact hd u hus (hp u hu)
    intro x hx hxl
    simp only [List.mem_cons] at hxl
    rcases hxl with rfl | hxl
    · exact hvs hx
    · refine ih ?_ x hx hxl
      intro y hy hyd
      simp only [List.mem_cons] at hyd
      rcases hyd with rfl | hyd
      · exact hvs hy
      · exact hd y hy hyd

/-- **A stuck set rules out every schedule**: the program deadlocks. -/
theorem no_schedule_of_stuck {g : DepGraph} {s : List Nat} (hs : Stuck g s)
    (hlt : ∀ x ∈ s, x < g.size) : ¬ ∃ l, Schedule g l := by
  rintro ⟨l, hv, hall⟩
  obtain ⟨x, hx⟩ := List.exists_mem_of_ne_nil s hs.1
  exact hs.never_fires hv (by simp) x hx (hall x (hlt x hx))

theorem no_schedule_of_stuckB {g : DepGraph} {s : List Nat} (h : stuckB g s = true)
    (hlt : ∀ x ∈ s, x < g.size) : ¬ ∃ l, Schedule g l :=
  no_schedule_of_stuck (stuck_of_stuckB h) hlt

/-- Kahn's algorithm: a schedule, or the nodes it could not fire (`Sum.inr`). Either answer is
checked before it is believed (`scheduleB`, `stuckB`). -/
def kahn (g : DepGraph) : List Nat ⊕ List Nat := Id.run do
  let n := g.size
  let mut done : Array Bool := Array.replicate n false
  let mut order : Array Nat := #[]
  -- Each round fires every node whose predecessors have all fired; at most n rounds.
  for _ in [0:n + 1] do
    let mut progressed := false
    for v in [0:n] do
      if !done[v]! && (g.predsOf v).all fun u => u < n && done[u]! then
        done := done.set! v true
        order := order.push v
        progressed := true
    if !progressed then break
  if order.size == n then return .inl order.toList
  return .inr ((List.range n).filter fun v => !done[v]!)

end DepGraph

end

end Veir.Air
