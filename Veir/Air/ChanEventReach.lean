module

public import Veir.Air.ChanFast

namespace Veir.Air

@[expose] public section

/-! # The race check on the event graph

`racesOk` asks, for pairs of positions of an execution, whether one happens before the other, and
answers through the reachability matrix of the graph on all positions: quadratic in the number of
labels, which is the number of stream elements. Here the question is first asked of a graph with
two nodes per event (its start and its finish), whose size is twice the number of events:

- a label comes before the finish of each event in `finishersL`, and after the start of each event
  in `startersL` (`hb_finishers`, `hb_starters`);
- each edge of the start/finish graph is a happens-before (`evGraph_edge`): an event's start
  before its finish, a dependency's finish before the event's start, and a put's start before the
  finish of a get receiving its elements (how channels order events);
- so a path from a finisher of `x` to a starter of `y` puts `x` before `y` (`eventReach_sound`).

Pairs this does not order get a short search back along `hbPredsI` (`localReach`), which orders
labels within one event. `racesOkR` is `racesOk` for any sound `reach`, and
`raceFree_of_racesOkR` its soundness. A pair neither orders is reported, never assumed ordered.
-/

namespace Chan

variable {p : Prog}

theorem HB.single {z y : Label} (h : z ∈ hbPreds p y) : HB p z y := .step (.refl z) h

theorem HB.trans {x y z : Label} (h₁ : HB p x y) (h₂ : HB p y z) : HB p x z := by
  induction h₂ with
  | refl => exact h₁
  | step _ hp ih => exact .step ih hp

/-- The event a label belongs to: an event's own start and finish; a stream element's put for
its read and its entry into the stream, its get for its arrival at a slot. `push` and `pull`
exist for buffered elements, `xfer` for the others. -/
def ownerL (p : Prog) : Label → Option Nat
  | .start v | .finish v => some v
  | .read k => (p.elems[k]?).bind (·.src)
  | .push k => (p.elems[k]?).bind fun e => if e.buffered then e.src else none
  | .xfer k => (p.elems[k]?).bind fun e => if e.buffered then none else e.src
  | .pull k i => (p.elems[k]?).bind fun e => if e.buffered then e.dsts[i]?.join else none

theorem mem_hbPreds_finish_sent {k v : Nat} {e : Elem} (hk : p.elems[k]? = some e)
    (hs : e.src = some v) : sentLabel p k ∈ hbPreds p (.finish v) := by
  simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range]
  exact Or.inr ⟨k, elem_lt hk, by simp [hk, hs]⟩

theorem mem_hbPreds_finish_got {k i d : Nat} {e : Elem} (hk : p.elems[k]? = some e)
    (hd : e.dsts[i]? = some (some d)) : gotLabel p k i ∈ hbPreds p (.finish d) := by
  simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range]
  refine Or.inr ⟨k, elem_lt hk, ?_⟩
  simp only [hk, List.mem_append, List.mem_filterMap, List.mem_range]
  exact Or.inr ⟨i, (List.getElem?_eq_some_iff.mp hd).1, by simp [hd]⟩

theorem hb_read_sent {k : Nat} {e : Elem} (hk : p.elems[k]? = some e) :
    HB p (.read k) (sentLabel p k) := by
  apply HB.single
  cases hb : e.buffered <;> simp [sentLabel, hbPreds, hk, hb]

/-- An event's start comes before each of its labels. -/
theorem hb_start_owner {x : Label} {v : Nat} (h : ownerL p x = some v) : HB p (.start v) x := by
  revert h
  cases x with
  | start w =>
    intro h
    simp only [ownerL, Option.some.injEq] at h; subst h; exact .refl _
  | finish w =>
    intro h
    simp only [ownerL, Option.some.injEq] at h; subst h
    exact HB.single (by simp [hbPreds])
  | read k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    exact HB.single (by simp [hbPreds, hk, hs, optL])
  | push k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · exact (HB.single (z := .start v) (y := .read k) (by simp [hbPreds, hk, hs, optL])).trans
        (HB.single (by simp [hbPreds, hk]))
    · cases hs
  | xfer k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · cases hs
    · exact (HB.single (z := .start v) (y := .read k) (by simp [hbPreds, hk, hs, optL])).trans
        (HB.single (by simp [hbPreds, hk]))
  | pull k i =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · have hd : e.dsts[i]? = some (some v) := by
        cases hdi : e.dsts[i]? with
        | none => simp [hdi] at hs
        | some o => rw [hdi] at hs; simp at hs; rw [hs]
      exact HB.single (by simp [hbPreds, hk, hd])
    · cases hs

/-- Each label of an event comes before its finish. -/
theorem hb_owner_finish {x : Label} {v : Nat} (h : ownerL p x = some v) : HB p x (.finish v) := by
  revert h
  cases x with
  | start w =>
    intro h
    simp only [ownerL, Option.some.injEq] at h; subst h
    exact HB.single (by simp [hbPreds])
  | finish w =>
    intro h
    simp only [ownerL, Option.some.injEq] at h; subst h; exact .refl _
  | read k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    exact (hb_read_sent hk).trans (HB.single (mem_hbPreds_finish_sent hk hs))
  | push k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · next hb =>
      have : sentLabel p k = .push k := by simp [sentLabel, hk, hb]
      exact HB.single (this ▸ mem_hbPreds_finish_sent hk hs)
    · cases hs
  | xfer k =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · cases hs
    · next hb =>
      have : sentLabel p k = .xfer k := by simp [sentLabel, hk, hb]
      exact HB.single (this ▸ mem_hbPreds_finish_sent hk hs)
  | pull k i =>
    intro h
    simp only [ownerL, Option.bind_eq_some_iff] at h
    obtain ⟨e, hk, hs⟩ := h
    split at hs
    · next hb =>
      have hd : e.dsts[i]? = some (some v) := by
        cases hdi : e.dsts[i]? with
        | none => simp [hdi] at hs
        | some o => rw [hdi] at hs; simp at hs; rw [hs]
      have : gotLabel p k i = .pull k i := by simp [gotLabel, hk, hb]
      exact HB.single (this ▸ mem_hbPreds_finish_got hk hd)
    · cases hs

/-- **Events the dependency graph orders**: `a`'s finish comes before `b`'s start. -/
theorem hb_finish_start {a b : Nat} (r : DepGraph.Reach p.graph a b) (hne : a ≠ b) :
    HB p (.finish a) (.start b) := by
  induction r with
  | refl => exact absurd rfl hne
  | @step w v rw hp ih =>
    have hfs : HB p (.finish w) (.start v) := HB.single (by simp [hbPreds, hp])
    by_cases haw : a = w
    · subst haw; exact hfs
    · exact ((ih haw).trans (HB.single (by simp [hbPreds]))).trans hfs

/-- The events a stream element is got by. -/
def dstsOf (e : Elem) : List Nat := e.dsts.filterMap id

theorem mem_dstsOf {e : Elem} {d : Nat} (h : d ∈ dstsOf e) : ∃ i : Nat, e.dsts[i]? = some (some d) := by
  simp only [dstsOf, List.mem_filterMap, id_eq] at h
  obtain ⟨o, ho, hod⟩ := h
  subst hod
  exact List.mem_iff_getElem?.mp ho

/-- Events whose finish comes after label `x`: its own event, and for an element in the stream,
the gets it reaches. -/
def finishersL (p : Prog) (x : Label) : List Nat :=
  (ownerL p x).toList ++
    match x with
    | .read k => match p.elems[k]? with | some e => dstsOf e | none => []
    | .push k => match p.elems[k]? with | some e => if e.buffered then dstsOf e else [] | none => []
    | .xfer k => match p.elems[k]? with | some e => if e.buffered then [] else dstsOf e | none => []
    | _ => []

/-- Events whose start comes before label `y`: its own event, the gets an unbuffered transfer
waits for, and the put a buffered arrival comes from. -/
def startersL (p : Prog) (y : Label) : List Nat :=
  (ownerL p y).toList ++
    match y with
    | .xfer k => match p.elems[k]? with | some e => if e.buffered then [] else dstsOf e | none => []
    | .pull k _ => match p.elems[k]? with | some e => if e.buffered then e.src.toList else [] | none => []
    | _ => []

theorem hb_finishers {x : Label} {a : Nat} (h : a ∈ finishersL p x) : HB p x (.finish a) := by
  unfold finishersL at h
  rcases List.mem_append.mp h with h | h
  · exact hb_owner_finish (Option.mem_toList.mp h)
  · cases x with
    | read k =>
      cases hk : p.elems[k]? with
      | none => simp [hk] at h
      | some e =>
        simp only [hk] at h
        obtain ⟨i, hd⟩ := mem_dstsOf h
        -- read, then the element enters the stream (push or xfer), then it arrives at slot i.
        cases hb : e.buffered with
        | true =>
          have hg : gotLabel p k i = .pull k i := by simp [gotLabel, hk, hb]
          exact ((HB.single (z := .read k) (y := .push k) (by simp [hbPreds, hk])).trans
            (HB.single (z := .push k) (y := .pull k i) (by simp [hbPreds, hk]))).trans
            (HB.single (hg ▸ mem_hbPreds_finish_got hk hd))
        | false =>
          have hg : gotLabel p k i = .xfer k := by simp [gotLabel, hk, hb]
          exact (HB.single (z := .read k) (y := .xfer k) (by simp [hbPreds, hk])).trans
            (HB.single (hg ▸ mem_hbPreds_finish_got hk hd))
    | push k =>
      cases hk : p.elems[k]? with
      | none => simp [hk] at h
      | some e =>
        simp only [hk] at h
        split at h
        · next hb =>
          obtain ⟨i, hd⟩ := mem_dstsOf h
          have hg : gotLabel p k i = .pull k i := by simp [gotLabel, hk, hb]
          exact (HB.single (z := .push k) (y := .pull k i) (by simp [hbPreds, hk])).trans
            (HB.single (hg ▸ mem_hbPreds_finish_got hk hd))
        · simp at h
    | xfer k =>
      cases hk : p.elems[k]? with
      | none => simp [hk] at h
      | some e =>
        simp only [hk] at h
        split at h
        · simp at h
        · next hb =>
          obtain ⟨i, hd⟩ := mem_dstsOf h
          have hg : gotLabel p k i = .xfer k := by simp [gotLabel, hk, hb]
          exact HB.single (hg ▸ mem_hbPreds_finish_got hk hd)
    | _ => simp at h

theorem hb_starters {y : Label} {b : Nat} (h : b ∈ startersL p y) : HB p (.start b) y := by
  unfold startersL at h
  rcases List.mem_append.mp h with h | h
  · exact hb_start_owner (Option.mem_toList.mp h)
  · cases y with
    | xfer k =>
      cases hk : p.elems[k]? with
      | none => simp [hk] at h
      | some e =>
        simp only [hk] at h
        split at h
        · simp at h
        · apply HB.single
          simp only [hbPreds, hk]
          apply List.mem_cons_of_mem
          apply List.mem_append_left
          exact List.mem_map_of_mem (f := Label.start) (by simpa [dstsOf] using h)
    | pull k i =>
      cases hk : p.elems[k]? with
      | none => simp [hk] at h
      | some e =>
        simp only [hk] at h
        split at h
        · have hs : e.src = some b := by simpa using h
          exact ((HB.single (z := .start b) (y := .read k) (by simp [hbPreds, hk, hs, optL])).trans
            (HB.single (z := .read k) (y := .push k) (by simp [hbPreds, hk]))).trans
            (HB.single (by simp [hbPreds, hk]))
        · simp at h
    | _ => simp at h

/-- Positions `i`, `j` of `t` hold labels `x`, `y` with `x` before `y`. -/
def PosHB (p : Prog) (t : List Label) (i j : Nat) : Prop :=
  ∀ y, t[j]? = some y → ∃ x, t[i]? = some x ∧ HB p x y

/-! ### The start/finish graph

Node `2v` is event `v`'s start, node `2v + 1` its finish. Edges (as predecessors):
- the finish of each event `v` depends on, before `v`'s start;
- `v`'s start before its finish;
- for each element `v` gets from a put `s`: `s`'s start before `v`'s finish (the element is read
  after `s` started, and must arrive before `v` finishes). This is where channels order events.
-/

/-- The label a node stands for. -/
def nodeLabel (n : Nat) : Label := if n % 2 = 0 then .start (n / 2) else .finish (n / 2)

/-- The puts whose elements event `v` gets, among the elements `idx` lists for `v`. -/
def putsInto (p : Prog) (idx : Array (List Nat)) (v : Nat) : List Nat :=
  (idx.getD v []).filterMap fun k =>
    match p.elems[k]? with
    | some e => if (some v) ∈ e.dsts then e.src else none
    | none => none

def evGraph (p : Prog) (idx : Array (List Nat)) : DepGraph :=
  ⟨(List.range (2 * p.graph.size)).toArray.map fun n =>
    if n % 2 = 0 then (p.graph.predsOf (n / 2)).map (2 * · + 1)
    else (n - 1) :: (putsInto p idx (n / 2)).map (2 * ·)⟩

theorem hb_put_get {s v k : Nat} {e : Elem} (hk : p.elems[k]? = some e) (hs : e.src = some s)
    (hd : (some v) ∈ e.dsts) : HB p (.start s) (.finish v) := by
  obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp hd
  have hread : HB p (.start s) (.read k) := HB.single (by simp [hbPreds, hk, hs, optL])
  cases hb : e.buffered with
  | true =>
    have hg : gotLabel p k i = .pull k i := by simp [gotLabel, hk, hb]
    exact ((hread.trans (HB.single (z := .read k) (y := .push k) (by simp [hbPreds, hk]))).trans
      (HB.single (z := .push k) (y := .pull k i) (by simp [hbPreds, hk]))).trans
      (HB.single (hg ▸ mem_hbPreds_finish_got hk hi))
  | false =>
    have hg : gotLabel p k i = .xfer k := by simp [gotLabel, hk, hb]
    exact (hread.trans (HB.single (z := .read k) (y := .xfer k) (by simp [hbPreds, hk]))).trans
      (HB.single (hg ▸ mem_hbPreds_finish_got hk hi))

theorem nodeLabel_even (v : Nat) : nodeLabel (2 * v) = .start v := by
  simp [nodeLabel]

theorem nodeLabel_odd (v : Nat) : nodeLabel (2 * v + 1) = .finish v := by
  simp only [nodeLabel]
  rw [if_neg (by omega)]
  congr 1; omega

/-- Each edge of the start/finish graph is a happens-before. -/
theorem evGraph_edge {idx : Array (List Nat)} {w n : Nat} (h : w ∈ (evGraph p idx).predsOf n) :
    HB p (nodeLabel w) (nodeLabel n) := by
  simp only [evGraph, DepGraph.predsOf, Array.getElem?_map, List.getElem?_toArray] at h
  by_cases hlt : n < 2 * p.graph.size
  · rw [List.getElem?_range hlt] at h
    simp only [Option.map_some, Option.getD_some] at h
    split at h
    · next hev =>
      obtain ⟨v, rfl⟩ : ∃ v, n = 2 * v := ⟨n / 2, by omega⟩
      have hv : 2 * v / 2 = v := by omega
      rw [hv] at h
      obtain ⟨u, hu, rfl⟩ := List.mem_map.mp h
      rw [nodeLabel_odd, nodeLabel_even]
      exact HB.single (by simpa [hbPreds, DepGraph.predsOf] using hu)
    · next hodd =>
      obtain ⟨v, rfl⟩ : ∃ v, n = 2 * v + 1 := ⟨n / 2, by omega⟩
      have hv : (2 * v + 1) / 2 = v := by omega
      have hm : 2 * v + 1 - 1 = 2 * v := by omega
      rw [hv, hm] at h
      rw [nodeLabel_odd]
      rcases List.mem_cons.mp h with rfl | h
      · rw [nodeLabel_even]
        exact HB.single (by simp [hbPreds])
      · obtain ⟨s, hs, rfl⟩ := List.mem_map.mp h
        rw [nodeLabel_even]
        simp only [putsInto, List.mem_filterMap] at hs
        obtain ⟨k, _, hk⟩ := hs
        cases hek : p.elems[k]? with
        | none => simp [hek] at hk
        | some e =>
          simp only [hek] at hk
          split at hk
          · next hd => exact hb_put_get hek hk hd
          · cases hk
  · rw [List.getElem?_eq_none (by simp; omega)] at h
    simp at h

theorem evGraph_reach {idx : Array (List Nat)} {a b : Nat}
    (r : DepGraph.Reach (evGraph p idx) a b) : HB p (nodeLabel a) (nodeLabel b) := by
  induction r with
  | refl => exact .refl _
  | step _ hp ih => exact ih.trans (evGraph_edge hp)

/-- Through the start/finish graph: an event finishing after the first label reaches an event
starting before the second. -/
def eventReach (p : Prog) (rows : Array Nat) (g : DepGraph) (arr : Array Label) (i j : Nat) : Bool :=
  match arr[i]?, arr[j]? with
  | some x, some y =>
    (finishersL p x).any fun a => (startersL p y).any fun b => g.reachFast rows (2 * a + 1) (2 * b)
  | _, _ => false

theorem eventReach_sound {idx : Array (List Nat)} {rows : Array Nat} {t : List Label} {i j : Nat}
    (hrows : rows = (evGraph p idx).reachRows)
    (h : eventReach p rows (evGraph p idx) t.toArray i j = true) : PosHB p t i j := by
  intro y hy
  unfold eventReach at h
  simp only [List.getElem?_toArray] at h
  cases hx : t[i]? with
  | none => simp [hx] at h
  | some x =>
    rw [hx, hy] at h
    simp only [List.any_eq_true] at h
    obtain ⟨a, ha, b, hb, hr⟩ := h
    subst hrows
    rw [DepGraph.reachFast_eq] at hr
    have r := evGraph_reach (DepGraph.reach_of_reachB hr)
    rw [nodeLabel_odd, nodeLabel_even] at r
    exact ⟨x, rfl, ((hb_finishers ha).trans r).trans (hb_starters hb)⟩

/-- Within an event, and between labels the event graph cannot tell apart: a path of at most `n`
`hbPredsI` steps back from `y` to `x`. -/
def localReach (p : Prog) (idx : Array (List Nat)) : Nat → Label → Label → Bool
  | 0, x, y => x == y
  | n + 1, x, y => x == y || (hbPredsI p idx y).any fun z => localReach p idx n x z

theorem localReach_sound {idx : Array (List Nat)} :
    ∀ (n : Nat) (x y : Label), localReach p idx n x y = true → HB p x y
  | 0, x, y, h => by
    simp only [localReach, beq_iff_eq] at h
    subst h; exact .refl _
  | n + 1, x, y, h => by
    simp only [localReach, Bool.or_eq_true, beq_iff_eq, List.any_eq_true] at h
    rcases h with h | ⟨z, hz, hr⟩
    · subst h; exact .refl _
    · exact (localReach_sound n x z hr).trans (HB.single (hbPredsI_sub hz))

/-- The event graph first, then a short path between the labels. -/
def labelReach (p : Prog) (idx : Array (List Nat)) (depth : Nat) (g : DepGraph)
    (rows : Array Nat) (arr : Array Label) (i j : Nat) : Bool :=
  eventReach p rows g arr i j ||
    match arr[i]?, arr[j]? with
    | some x, some y => localReach p idx depth x y
    | _, _ => false

theorem labelReach_sound {idx : Array (List Nat)} {depth : Nat} {g : DepGraph} {rows : Array Nat}
    {t : List Label} {i j : Nat} (hg : g = evGraph p idx) (hrows : rows = g.reachRows)
    (h : labelReach p idx depth g rows t.toArray i j = true) : PosHB p t i j := by
  unfold labelReach at h
  simp only [Bool.or_eq_true] at h
  rcases h with h | h
  · subst hg; exact eventReach_sound hrows h
  · intro y hy
    simp only [List.getElem?_toArray] at h
    cases hx : t[i]? with
    | none => simp [hx] at h
    | some x =>
      rw [hx, hy] at h
      exact ⟨x, rfl, localReach_sound _ _ _ h⟩

/-! ### The race check with any sound `reach` -/

def racesOkR (reach : Nat → Nat → Bool) (fp : LFp) (t : List Label) : Bool :=
  (groups (emitted fp t)).toList.all fun (_, arr) => scanOk reach 0 none [] arr.toList

/-- **The race check is sound** for any `reach` that only claims orders `HB` has. -/
theorem raceFree_of_racesOkR {reach : Nat → Nat → Bool} {fp : LFp} {t : List Label}
    (hs : ∀ i j, reach i j = true → PosHB p t i j) (h : racesOkR reach fp t = true) :
    RaceFree p fp (· ∈ t) := by
  intro x y hx hy hne hc
  obtain ⟨a, ha, b, hb, hbuf, hw, el, hela, helb⟩ := hc
  have gx : t[t.idxOf x]? = some x := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hx), List.getElem_idxOf]
  have gy : t[t.idxOf y]? = some y := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hy), List.getElem_idxOf]
  have hij : t.idxOf x ≠ t.idxOf y := fun e => hne (by rw [e] at gx; rw [gx] at gy; cases gy; rfl)
  have ex := group_mem (mem_emitted gx ha hela)
  have ey := group_mem (mem_emitted gy hb helb)
  simp only at ex ey
  rw [← hbuf] at ey
  let l : Loc := (a.buf, el)
  have hscan : scanOk reach 0 none [] ((groups (emitted fp t)).getD l #[]).toList = true := by
    rw [Std.HashMap.getD_eq_getD_getElem?]
    cases hl : (groups (emitted fp t))[l]? with
    | none => simp [scanOk]
    | some arr =>
      simp only [racesOkR, List.all_eq_true] at h
      exact h (l, arr) (Std.HashMap.mem_toList_iff_getElem?_eq_some.mpr hl)
  have pairs := scanOk_sound (R := PosHB p t)
    (fun i y hy => ⟨y, hy, .refl y⟩)
    (fun a b c h₁ h₂ y hy => by
      obtain ⟨z, hz, hzy⟩ := h₂ y hy
      obtain ⟨x, hx, hxz⟩ := h₁ z hz
      exact ⟨x, hx, hxz.trans hzy⟩)
    hs _ [] 0 none [] hscan ⟨by simp, by simp, by simp, by simp [PairsOk]⟩
  simp only [List.nil_append] at pairs
  have hwr : (a.kind == .write) = true ∨ (b.kind == .write) = true := by
    rcases hw with h | h <;> simp [h]
  rcases Nat.lt_or_gt_of_ne hij with hlt | hlt
  · obtain ⟨x', hx', hb'⟩ := pairs _ ex _ ey hlt hwr y gy
    rw [gx] at hx'; cases hx'; exact Or.inl hb'
  · obtain ⟨y', hy', hb'⟩ := pairs _ ey _ ex hlt hwr.symm x gx
    rw [gy] at hy'; cases hy'; exact Or.inr hb'

/-- How many `hbPredsI` steps `labelReach` follows within an event. -/
def localDepth : Nat := 3

/-- The race check through the event graph, then short paths between labels. The graph and its
rows are built once. -/
def racesOkE (p : Prog) (idx : Array (List Nat)) (fp : LFp) (t : List Label) : Bool :=
  let g := evGraph p idx
  racesOkR (labelReach p idx localDepth g g.reachRows t.toArray) fp t

theorem raceFree_of_racesOkE {idx : Array (List Nat)} {fp : LFp} {t : List Label}
    (h : racesOkE p idx fp t = true) : RaceFree p fp (· ∈ t) :=
  raceFree_of_racesOkR (fun _ _ hr => labelReach_sound rfl rfl hr) h

/-- **The fast check, end to end, through the event graph**: `outcome_uniqueH` with `racesOkE`. -/
theorem outcome_uniqueE {V : Type} {fp : LFp} {eff : Label → Mem V → Mem V} {idx : Array (List Nat)}
    {t : List Label} (hw : wfB p = true) (hfr : LFramed fp eff)
    (hc : checkH p idx t = some true) (hr : racesOkE p idx fp t = true)
    {t' G : List Label} (h : Run p [] t' G) (d : Done p G) (m : Mem V) :
    runL eff t' m = runL eff t m := by
  obtain ⟨G₀, r, d₀⟩ := checkH_true hc
  exact (deterministic (wf_of_wfB hw) hfr r d₀ h d (raceFree_of_racesOkE hr) m).symm

/-- Witnesses for a failed `racesOkE` (not proven; only for messages). -/
def raceWitnessesE (p : Prog) (idx : Array (List Nat)) (fp : LFp) (t : List Label) :
    List (Nat × Nat) :=
  let g := evGraph p idx
  let reach := labelReach p idx localDepth g g.reachRows t.toArray
  ((groups (emitted fp t)).toList.flatMap fun (_, arr) => scanReport reach arr.toList).eraseDups

end Chan

end

end Veir.Air
