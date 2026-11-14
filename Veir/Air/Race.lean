module

public import Veir.Air.DepGraph

namespace Veir.Air

@[expose] public section

/-! # Races

Each event reads and writes elements of buffers. Two events *conflict* when they touch a common
element of a common buffer and at least one of them writes it: RAW, WAR or WAW (`SEMANTICS.md`,
D6). A program is *race-free* when every pair of conflicting events is ordered by a token path,
one way or the other. Making it so is `air-dependency`'s job (D6). An event that only reads
conflicts with nothing that only reads: reads after reads need no order.

Buffers are numbered; which numbers name the same memory is decided when a program is read, not
here. Elements are linear positions (`Veir.Air.positions`).
-/

inductive AccessKind where
  | read
  | write
deriving DecidableEq, Repr, Inhabited

structure Access where
  buf : Nat
  kind : AccessKind
  elems : List Int
deriving Repr, Inhabited

/-- Two accesses conflict: same buffer, a common element, and at least one write. -/
def Access.Conflicts (a b : Access) : Prop :=
  a.buf = b.buf ∧ (a.kind = .write ∨ b.kind = .write) ∧ ∃ x, x ∈ a.elems ∧ x ∈ b.elems

def Access.conflictsB (a b : Access) : Bool :=
  a.buf == b.buf && (a.kind == .write || b.kind == .write) && a.elems.any (b.elems.contains ·)

theorem Access.conflictsB_iff {a b : Access} : a.conflictsB b = true ↔ a.Conflicts b := by
  simp [Access.conflictsB, Access.Conflicts, List.any_eq_true]
  grind

/-- What each event reads and writes. -/
abbrev Footprint := Nat → List Access

/-- Two events conflict. -/
def EventsConflict (fp : Footprint) (u v : Nat) : Prop :=
  ∃ a ∈ fp u, ∃ b ∈ fp v, a.Conflicts b

def eventsConflictB (fp : Footprint) (u v : Nat) : Bool :=
  (fp u).any fun a => (fp v).any fun b => a.conflictsB b

theorem eventsConflictB_iff {fp : Footprint} {u v : Nat} :
    eventsConflictB fp u v = true ↔ EventsConflict fp u v := by
  simp [eventsConflictB, EventsConflict, List.any_eq_true, Access.conflictsB_iff]

theorem Access.Conflicts.symm {a b : Access} (h : a.Conflicts b) : b.Conflicts a := by
  obtain ⟨hb, hw, x, ha, hb'⟩ := h
  exact ⟨hb.symm, hw.symm, x, hb', ha⟩

theorem EventsConflict.symm {fp : Footprint} {u v : Nat} (h : EventsConflict fp u v) :
    EventsConflict fp v u := by
  obtain ⟨a, ha, b, hb, h⟩ := h
  exact ⟨b, hb, a, ha, h.symm⟩

/-- Every pair of distinct conflicting events is ordered by a token path. -/
def RaceFree (g : DepGraph) (fp : Footprint) : Prop :=
  ∀ u v, u < g.size → v < g.size → u ≠ v → EventsConflict fp u v →
    DepGraph.Reach g u v ∨ DepGraph.Reach g v u

/-- The conflicting pairs `u < v` that no token path orders, which on a forward graph are exactly
the races. -/
def races (g : DepGraph) (fp : Footprint) : List (Nat × Nat) :=
  (List.range g.size).flatMap fun v =>
    (List.range v).filterMap fun u =>
      if eventsConflictB fp u v && !g.reachB u v then some (u, v) else none

def raceFreeB (g : DepGraph) (fp : Footprint) : Bool := (races g fp).isEmpty

theorem mem_races {g : DepGraph} {fp : Footprint} {u v : Nat} :
    (u, v) ∈ races g fp ↔ v < g.size ∧ u < v ∧ EventsConflict fp u v ∧ g.reachB u v = false := by
  simp only [races, List.mem_flatMap, List.mem_range, List.mem_filterMap]
  constructor
  · rintro ⟨v', hv', u', hu', h⟩
    split at h
    · next hc =>
      simp only [Option.some.injEq, Prod.mk.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at hc
      exact ⟨hv', hu', eventsConflictB_iff.mp hc.1, hc.2⟩
    · simp at h
  · rintro ⟨hv, hu, hc, hr⟩
    refine ⟨v, hv, u, hu, ?_⟩
    simp [eventsConflictB_iff.mpr hc, hr]

/-- **The race checker is exact** on forward graphs. -/
theorem raceFreeB_iff {g : DepGraph} {fp : Footprint} (hf : g.Forward) :
    raceFreeB g fp = true ↔ RaceFree g fp := by
  constructor
  · intro h u v hu hv hne hc
    have hnil : races g fp = [] := List.isEmpty_iff.mp h
    -- Order the pair; the earlier event must reach the later one.
    rcases Nat.lt_or_gt_of_ne hne with hlt | hlt
    · left
      apply DepGraph.reach_of_reachB
      cases hb : g.reachB u v
      · have : (u, v) ∈ races g fp := mem_races.mpr ⟨hv, hlt, hc, hb⟩
        simp [hnil] at this
      · rfl
    · right
      apply DepGraph.reach_of_reachB
      cases hb : g.reachB v u
      · have : (v, u) ∈ races g fp := mem_races.mpr ⟨hu, hlt, hc.symm, hb⟩
        simp [hnil] at this
      · rfl
  · intro h
    apply List.isEmpty_iff.mpr
    apply List.eq_nil_iff_forall_not_mem.mpr
    rintro ⟨u, v⟩ hm
    obtain ⟨hv, hlt, hc, hb⟩ := mem_races.mp hm
    rcases h u v (Nat.lt_trans hlt hv) hv (Nat.ne_of_lt hlt) hc with r | r
    · rw [DepGraph.reachB_of_reach hf r] at hb; cases hb
    · exact absurd (r.le hf) (Nat.not_le_of_lt hlt)

/-- Race-freedom depends only on reachability. -/
theorem raceFree_iff_of_reach {g h : DepGraph} {fp : Footprint} (size : g.size = h.size)
    (reach : ∀ u v, DepGraph.Reach g u v ↔ DepGraph.Reach h u v) :
    RaceFree g fp ↔ RaceFree h fp := by
  constructor
  · intro hg u v hu hv hne hc
    rcases hg u v (size ▸ hu) (size ▸ hv) hne hc with r | r
    · exact Or.inl ((reach u v).mp r)
    · exact Or.inr ((reach v u).mp r)
  · intro hh u v hu hv hne hc
    rcases hh u v (size ▸ hu) (size ▸ hv) hne hc with r | r
    · exact Or.inl ((reach u v).mpr r)
    · exact Or.inr ((reach v u).mpr r)

/-- **`air-dependency-canonicalize` cannot create a race**, nor hide one. -/
theorem raceFree_reduce_iff {g : DepGraph} {fp : Footprint} (hf : g.Forward) :
    RaceFree g.reduce fp ↔ RaceFree g fp :=
  raceFree_iff_of_reach (DepGraph.size_reduce g) fun _ _ => DepGraph.reach_reduce_iff hf

/-- Nor can any rewrite the checker accepts. -/
theorem raceFree_of_sameReach {g h : DepGraph} {fp : Footprint} (hc : DepGraph.sameReach g h = true) :
    RaceFree g fp ↔ RaceFree h fp :=
  have ⟨size, _, _, reach⟩ := DepGraph.sameReach_sound hc
  raceFree_iff_of_reach size reach

end

end Veir.Air
