module

public import Veir.Air.ChanEventReach

namespace Veir.Air

@[expose] public section

/-! # Chunked transfers (phase 1, `SCALE_DESIGN.md` §2)

A *chunk* is a run of consecutive elements of one stream that one put sends to the same gets,
all buffered or all not. The chunked program has one element per chunk; its labels stand for
their members' (`up`). The checkers run on the chunked program; this file proves that their
verdicts hold of the element program:
- HB of the chunked program gives HB of the element program (`hb_transfer`): between every pair
  of members, or, along the chunk's own steps (its read, entry, arrival), between members in
  stream order;
- so race-freedom transfers (`raceFree_of_chunked`) when no member reads where an earlier member
  of its chunk writes (`CondOk`);
- an execution completes in one program iff in the other (`completes_iff`).
-/

namespace Chan

/-- A chunking of a program's elements: the members of each chunk in stream order, and each
element's chunk and position in it. -/
structure Chunking where
  members : Array (Array Nat)
  cOf : Array Nat
  pos : Array Nat
deriving Inhabited

namespace Chunking

variable (ch : Chunking)

def mem (c a : Nat) : Nat := ch.members[c]![a]!
def len (c : Nat) : Nat := ch.members[c]!.size
def chunk (k : Nat) : Nat := ch.cOf[k]!
def idx (k : Nat) : Nat := ch.pos[k]!

end Chunking

variable {p : Prog} {ch : Chunking}

/-- The element program's element `k`. -/
def Prog.el (p : Prog) (k : Nat) : Elem := p.elems[k]!

/-- What makes a chunking one: every element is a member; members follow each other in their
stream; they have the same put, gets and buffering; a chunk's first member follows the last one of
another chunk, if anything. -/
structure Valid (p : Prog) (ch : Chunking) : Prop where
  cover : ∀ k, k < p.elems.size → ch.chunk k < ch.members.size ∧ ch.idx k < ch.len (ch.chunk k) ∧
    ch.mem (ch.chunk k) (ch.idx k) = k
  mem : ∀ c, c < ch.members.size → ∀ a, a < ch.len c →
    ch.chunk (ch.mem c a) = c ∧ ch.idx (ch.mem c a) = a ∧ ch.mem c a < p.elems.size
  nonempty : ∀ c, c < ch.members.size → 0 < ch.len c
  prev : ∀ c, c < ch.members.size → ∀ a, a + 1 < ch.len c →
    (p.el (ch.mem c (a + 1))).prev = some (ch.mem c a)
  same : ∀ c, c < ch.members.size → ∀ a, a < ch.len c →
    (p.el (ch.mem c a)).src = (p.el (ch.mem c 0)).src ∧
    (p.el (ch.mem c a)).dsts = (p.el (ch.mem c 0)).dsts ∧
    (p.el (ch.mem c a)).buffered = (p.el (ch.mem c 0)).buffered
  first : ∀ c, c < ch.members.size → ∀ j, (p.el (ch.mem c 0)).prev = some j →
    j < p.elems.size ∧ ch.idx j + 1 = ch.len (ch.chunk j)
  /-- A chunk does not follow itself. -/
  notSelf : ∀ c, c < ch.members.size → ∀ j, (p.el (ch.mem c 0)).prev = some j → ch.chunk j ≠ c
  /-- Unbuffered members follow each other through their gets: a chunk of several has some. -/
  xferDsts : ∀ c, c < ch.members.size → 1 < ch.len c → (p.el (ch.mem c 0)).buffered = false →
    (p.el (ch.mem c 0)).dsts ≠ []

/-- The chunked program: one element per chunk, as its first member, following the chunk of the
element its first member follows. -/
def chunked (p : Prog) (ch : Chunking) : Prog where
  graph := p.graph
  elems := (List.range ch.members.size).toArray.map fun c =>
    let e := p.el (ch.mem c 0)
    { e with prev := e.prev.map ch.chunk }

/-- A label of the element program as a label of the chunked one. -/
def up (ch : Chunking) : Label → Label
  | .start v => .start v
  | .finish v => .finish v
  | .read k => .read (ch.chunk k)
  | .push k => .push (ch.chunk k)
  | .pull k i => .pull (ch.chunk k) i
  | .xfer k => .xfer (ch.chunk k)

/-- The element a label is of, if any. -/
def elemOf : Label → Option Nat
  | .start _ | .finish _ => none
  | .read k | .push k | .pull k _ | .xfer k => some k

/-- A label of an element that exists. -/
def LOk (p : Prog) (x : Label) : Prop := ∀ k, elemOf x = some k → k < p.elems.size

theorem el_some {k : Nat} (h : k < p.elems.size) : p.elems[k]? = some (p.el k) := by
  simp [Prog.el, h]

theorem chunked_elem (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    (chunked p ch).elems[ch.chunk k]? =
      some { p.el (ch.mem (ch.chunk k) 0) with prev := (p.el (ch.mem (ch.chunk k) 0)).prev.map ch.chunk } := by
  have hc := (hv.cover k hk).1
  simp [chunked, hc]

/-- A member has its chunk's put, gets and buffering. -/
theorem same_k (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    (p.el k).src = (p.el (ch.mem (ch.chunk k) 0)).src ∧
    (p.el k).dsts = (p.el (ch.mem (ch.chunk k) 0)).dsts ∧
    (p.el k).buffered = (p.el (ch.mem (ch.chunk k) 0)).buffered := by
  obtain ⟨hc, hi, hm⟩ := hv.cover k hk
  have := hv.same _ hc _ hi
  rw [hm] at this
  exact this

/-! ### Order along a chunk -/

theorem hb_single {z y : Label} (h : z ∈ hbPreds p y) : HB p z y := HB.single h

/-- A member's read comes after the previous member's. -/
theorem hb_read_prev (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a + 1 < ch.len c) :
    HB p (.read (ch.mem c a)) (.read (ch.mem c (a + 1))) := by
  apply HB.single
  have hk := (hv.mem c hc (a + 1) ha).2.2
  simp [hbPreds, el_some hk, hv.prev c hc a ha, optL]

/-- The labels `L m_a → L m_(a+1)` of a chunk's consecutive members, per kind. -/
theorem step_push (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a + 1 < ch.len c)
    (hb : (p.el (ch.mem c 0)).buffered = true) :
    HB p (.push (ch.mem c a)) (.push (ch.mem c (a + 1))) := by
  apply HB.single
  have hk := (hv.mem c hc (a + 1) ha).2.2
  have hk' := (hv.mem c hc a (by omega)).2.2
  have hba : (p.el (ch.mem c a)).buffered = true := by rw [(hv.same c hc a (by omega)).2.2, hb]
  simp [hbPreds, el_some hk, hv.prev c hc a ha, optL, sentLabel, el_some hk', hba]

theorem step_pull (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a + 1 < ch.len c)
    (hb : (p.el (ch.mem c 0)).buffered = true) (i : Nat) :
    HB p (.pull (ch.mem c a) i) (.pull (ch.mem c (a + 1)) i) := by
  apply HB.single
  have hk := (hv.mem c hc (a + 1) ha).2.2
  have hk' := (hv.mem c hc a (by omega)).2.2
  have hba : (p.el (ch.mem c a)).buffered = true := by rw [(hv.same c hc a (by omega)).2.2, hb]
  simp [hbPreds, el_some hk, hv.prev c hc a ha, optL, gotLabel, el_some hk', hba]

theorem step_xfer (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a + 1 < ch.len c)
    (hb : (p.el (ch.mem c 0)).buffered = false) :
    HB p (.xfer (ch.mem c a)) (.xfer (ch.mem c (a + 1))) := by
  apply HB.single
  have hk := (hv.mem c hc (a + 1) ha).2.2
  have hk' := (hv.mem c hc a (by omega)).2.2
  have hba : (p.el (ch.mem c a)).buffered = false := by rw [(hv.same c hc a (by omega)).2.2, hb]
  have hd := hv.xferDsts c hc (by omega) hb
  have hd' : (p.el (ch.mem c (a + 1))).dsts ≠ [] := by
    rw [(hv.same c hc (a + 1) ha).2.1]; exact hd
  obtain ⟨o, os, hos⟩ : ∃ o os, (p.el (ch.mem c (a + 1))).dsts = o :: os := by
    cases h : (p.el (ch.mem c (a + 1))).dsts with
    | nil => exact absurd h hd'
    | cons o os => exact ⟨o, os, rfl⟩
  simp only [hbPreds, el_some hk, hv.prev c hc a ha, List.mem_cons, List.mem_append, List.mem_map,
    List.mem_range]
  exact Or.inr ⟨0, by simp [hos], by simp [gotLabel, el_some hk', hba]⟩

/-- Members' labels of one kind follow stream order: `L m_a` before `L m_b` for `a ≤ b`, when
each step `L m_a → L m_(a+1)` of the chunk is ordered. -/
theorem hb_chain (L : Nat → Label) {c : Nat} (hstep : ∀ a, a + 1 < ch.len c →
    HB p (L (ch.mem c a)) (L (ch.mem c (a + 1)))) {a b : Nat}
    (hab : a ≤ b) (hb : b < ch.len c) : HB p (L (ch.mem c a)) (L (ch.mem c b)) := by
  induction b with
  | zero => have : a = 0 := by omega
            subst this; exact .refl _
  | succ b ih =>
    rcases Nat.lt_or_eq_of_le hab with h | h
    · exact (ih (by omega) (by omega)).trans (hstep b hb)
    · subst h; exact .refl _

/-- A label of an element that exists, of the kind its buffering allows (the others never fire). -/
def Kinded (p : Prog) : Label → Prop
  | .start _ | .finish _ => True
  | .read k => k < p.elems.size
  | .push k | .pull k _ => k < p.elems.size ∧ (p.el k).buffered = true
  | .xfer k => k < p.elems.size ∧ (p.el k).buffered = false

/-- A member's position in its chunk; 0 for an event's labels. -/
def eidx (ch : Chunking) (x : Label) : Nat := match elemOf x with
  | some k => ch.idx k
  | none => 0

theorem buffered_k (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    (p.el k).buffered = (p.el (ch.mem (ch.chunk k) 0)).buffered := (same_k hv hk).2.2

/-- Every member of a chunk, as `mem c (idx k)`. -/
theorem mem_idx (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    ch.mem (ch.chunk k) (ch.idx k) = k := (hv.cover k hk).2.2

theorem sent_mem (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a < ch.len c) :
    sentLabel p (ch.mem c a) =
      if (p.el (ch.mem c 0)).buffered then .push (ch.mem c a) else .xfer (ch.mem c a) := by
  have hk := (hv.mem c hc a ha).2.2
  simp [sentLabel, el_some hk, (hv.same c hc a ha).2.2]

theorem got_mem (hv : Valid p ch) {c a : Nat} (hc : c < ch.members.size) (ha : a < ch.len c) (i : Nat) :
    gotLabel p (ch.mem c a) i =
      if (p.el (ch.mem c 0)).buffered then .pull (ch.mem c a) i else .xfer (ch.mem c a) := by
  have hk := (hv.mem c hc a ha).2.2
  simp [gotLabel, el_some hk, (hv.same c hc a ha).2.2]

/-- Entries into the stream follow stream order within a chunk. -/
theorem hb_sent_chain (hv : Valid p ch) {c a b : Nat} (hc : c < ch.members.size) (hab : a ≤ b)
    (hb : b < ch.len c) : HB p (sentLabel p (ch.mem c a)) (sentLabel p (ch.mem c b)) := by
  rw [sent_mem hv hc (by omega), sent_mem hv hc hb]
  cases hbuf : (p.el (ch.mem c 0)).buffered
  · exact hb_chain (fun k => .xfer k) (fun a' ha' => step_xfer hv hc ha' hbuf) hab hb
  · exact hb_chain (fun k => .push k) (fun a' ha' => step_push hv hc ha' hbuf) hab hb

/-- Arrivals at a slot follow stream order within a chunk. -/
theorem hb_got_chain (hv : Valid p ch) {c a b : Nat} (hc : c < ch.members.size) (hab : a ≤ b)
    (hb : b < ch.len c) (i : Nat) : HB p (gotLabel p (ch.mem c a) i) (gotLabel p (ch.mem c b) i) := by
  rw [got_mem hv hc (by omega), got_mem hv hc hb]
  cases hbuf : (p.el (ch.mem c 0)).buffered
  · exact hb_chain (fun k => .xfer k) (fun a' ha' => step_xfer hv hc ha' hbuf) hab hb
  · exact hb_chain (fun k => .pull k i) (fun a' ha' => step_pull hv hc ha' hbuf i) hab hb

theorem hb_read_chain (hv : Valid p ch) {c a b : Nat} (hc : c < ch.members.size) (hab : a ≤ b)
    (hb : b < ch.len c) : HB p (.read (ch.mem c a)) (.read (ch.mem c b)) :=
  hb_chain (fun k => .read k) (fun _ ha' => hb_read_prev hv hc ha') hab hb

/-! ### From one chunk to the next -/

/-- The element a chunk's first member follows is the last member of its own chunk. -/
theorem prev_last (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) :
    j < p.elems.size ∧ ch.chunk j < ch.members.size ∧ ch.mem (ch.chunk j) (ch.len (ch.chunk j) - 1) = j := by
  obtain ⟨hjs, hlast⟩ := hv.first c hc j hj
  obtain ⟨hcj, _, hm⟩ := hv.cover j hjs
  refine ⟨hjs, hcj, ?_⟩
  rw [show ch.len (ch.chunk j) - 1 = ch.idx j by omega]
  exact hm

/-- Through the link between chunks: any member's `L₁` of the previous chunk comes before any
member's `L₂` of the next one. -/
theorem hb_link (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) (L₁ L₂ : Nat → Label)
    (hchain₁ : ∀ a b, a ≤ b → b < ch.len (ch.chunk j) →
      HB p (L₁ (ch.mem (ch.chunk j) a)) (L₁ (ch.mem (ch.chunk j) b)))
    (hedge : HB p (L₁ j) (L₂ (ch.mem c 0)))
    (hchain₂ : ∀ b, b < ch.len c → HB p (L₂ (ch.mem c 0)) (L₂ (ch.mem c b)))
    {k' : Nat} (hk' : k' < p.elems.size) (hkc : ch.chunk k' = ch.chunk j) {b : Nat} (hb : b < ch.len c) :
    HB p (L₁ k') (L₂ (ch.mem c b)) := by
  obtain ⟨_, hcj, hlast⟩ := prev_last hv hc hj
  obtain ⟨_, hik, hmk⟩ := hv.cover k' hk'
  rw [hkc] at hik hmk
  have h1 : HB p (L₁ k') (L₁ j) := by
    have := hchain₁ (ch.idx k') (ch.len (ch.chunk j) - 1) (by omega) (by omega)
    rwa [hmk, hlast] at this
  exact h1.trans (hedge.trans (hchain₂ b hb))

theorem edge_read (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) : HB p (.read j) (.read (ch.mem c 0)) := by
  apply HB.single
  have hk := (hv.mem c hc 0 (hv.nonempty c hc)).2.2
  simp [hbPreds, el_some hk, hj, optL]

theorem edge_sent (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) : HB p (sentLabel p j) (.push (ch.mem c 0)) := by
  apply HB.single
  have hk := (hv.mem c hc 0 (hv.nonempty c hc)).2.2
  simp [hbPreds, el_some hk, hj, optL]

theorem edge_got_pull (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) (i : Nat) :
    HB p (gotLabel p j i) (.pull (ch.mem c 0) i) := by
  apply HB.single
  have hk := (hv.mem c hc 0 (hv.nonempty c hc)).2.2
  simp [hbPreds, el_some hk, hj, optL]

theorem edge_got_xfer (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) {i : Nat} (hi : i < (p.el (ch.mem c 0)).dsts.length) :
    HB p (gotLabel p j i) (.xfer (ch.mem c 0)) := by
  apply HB.single
  have hk := (hv.mem c hc 0 (hv.nonempty c hc)).2.2
  simp only [hbPreds, el_some hk, hj, List.mem_cons, List.mem_append, List.mem_map, List.mem_range]
  exact Or.inr ⟨i, hi, rfl⟩

/-! ### The chunked program's order, member by member -/

/-- The chunked program's element `c`, for a chunk. -/
def ecOf (p : Prog) (ch : Chunking) (c : Nat) : Elem :=
  { p.el (ch.mem c 0) with prev := (p.el (ch.mem c 0)).prev.map ch.chunk }

theorem chunked_get (c : Nat) :
    (chunked p ch).elems[c]? = if c < ch.members.size then some (ecOf p ch c) else none := by
  by_cases hc : c < ch.members.size
  · simp [chunked, hc, ecOf]
  · simp [chunked, hc]

theorem chunked_size : (chunked p ch).elems.size = ch.members.size := by simp [chunked]

/-- The chunked program's entry label of a chunk, as its members'. -/
theorem sent_chunked {c : Nat} (hc : c < ch.members.size) :
    sentLabel (chunked p ch) c =
      if (p.el (ch.mem c 0)).buffered then .push c else .xfer c := by
  simp [sentLabel, chunked_get, hc, ecOf]

theorem got_chunked {c : Nat} (hc : c < ch.members.size) (i : Nat) :
    gotLabel (chunked p ch) c i =
      if (p.el (ch.mem c 0)).buffered then .pull c i else .xfer c := by
  simp [gotLabel, chunked_get, hc, ecOf]

theorem preds_read {c : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.read c)) :
    c < ch.members.size ∧ ((∃ s, (p.el (ch.mem c 0)).src = some s ∧ W = .start s) ∨
      (∃ j, (p.el (ch.mem c 0)).prev = some j ∧ W = .read (ch.chunk j))) := by
  by_cases hc : c < ch.members.size
  · refine ⟨hc, ?_⟩
    simp only [hbPreds, chunked_get, hc, ite_true, ecOf, List.mem_append, optL] at h
    rcases h with h | h
    · left
      cases hs : (p.el (ch.mem c 0)).src with
      | none => simp [hs] at h
      | some s => simp [hs] at h; exact ⟨s, rfl, h⟩
    · right
      cases hp : (p.el (ch.mem c 0)).prev with
      | none => simp [hp] at h
      | some j => simp [hp] at h; exact ⟨j, rfl, h⟩
  · simp [hbPreds, chunked_get, hc] at h

theorem preds_push {c : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.push c)) :
    c < ch.members.size ∧ (W = .read c ∨
      (∃ j, (p.el (ch.mem c 0)).prev = some j ∧ W = sentLabel (chunked p ch) (ch.chunk j))) := by
  by_cases hc : c < ch.members.size
  · refine ⟨hc, ?_⟩
    simp only [hbPreds, chunked_get, hc, ite_true, ecOf, List.mem_cons, optL] at h
    rcases h with h | h
    · exact Or.inl h
    · right
      cases hp : (p.el (ch.mem c 0)).prev with
      | none => simp [hp] at h
      | some j => simp [hp] at h; exact ⟨j, rfl, h⟩
  · simp [hbPreds, chunked_get, hc] at h

theorem preds_pull {c i : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.pull c i)) :
    c < ch.members.size ∧ (W = .push c ∨
      (∃ d, (p.el (ch.mem c 0)).dsts[i]? = some (some d) ∧ W = .start d) ∨
      (∃ j, (p.el (ch.mem c 0)).prev = some j ∧ W = gotLabel (chunked p ch) (ch.chunk j) i)) := by
  by_cases hc : c < ch.members.size
  · refine ⟨hc, ?_⟩
    simp only [hbPreds, chunked_get, hc, ite_true, ecOf, List.mem_cons, List.mem_append, optL] at h
    rcases h with (h | h) | h
    · exact Or.inl h
    · right; left
      cases hd : (p.el (ch.mem c 0)).dsts[i]? with
      | none => simp [hd] at h
      | some o =>
        cases o with
        | none => simp [hd] at h
        | some d => simp [hd] at h; exact ⟨d, rfl, h⟩
    · right; right
      revert h
      cases hp : (p.el (ch.mem c 0)).prev with
      | none => simp
      | some j => intro h; simp at h; exact ⟨j, rfl, h⟩
  · simp [hbPreds, chunked_get, hc] at h

theorem preds_xfer {c : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.xfer c)) :
    c < ch.members.size ∧ (W = .read c ∨
      (∃ d, some d ∈ (p.el (ch.mem c 0)).dsts ∧ W = .start d) ∨
      (∃ j i, (p.el (ch.mem c 0)).prev = some j ∧ i < (p.el (ch.mem c 0)).dsts.length ∧
        W = gotLabel (chunked p ch) (ch.chunk j) i)) := by
  by_cases hc : c < ch.members.size
  · refine ⟨hc, ?_⟩
    simp only [hbPreds, chunked_get, hc, ite_true, ecOf, List.mem_cons, List.mem_append] at h
    rcases h with (h | h) | h
    · exact Or.inl h
    · right; left
      simp only [List.mem_map, List.mem_filterMap, id] at h
      obtain ⟨d, ⟨o, ho, hod⟩, rfl⟩ := h
      subst hod
      exact ⟨d, ho, rfl⟩
    · right; right
      revert h
      cases hp : (p.el (ch.mem c 0)).prev with
      | none => simp
      | some j =>
        intro h
        simp only [Option.map_some, List.mem_map, List.mem_range] at h
        obtain ⟨i, hi, rfl⟩ := h
        exact ⟨j, i, rfl, hi, rfl⟩
  · simp [hbPreds, chunked_get, hc] at h

theorem preds_start {v : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.start v)) :
    ∃ u, u ∈ p.graph.predsOf v ∧ W = .finish u := by
  simp only [hbPreds, chunked, List.mem_map] at h
  obtain ⟨u, hu, rfl⟩ := h
  exact ⟨u, hu, rfl⟩

theorem preds_finish {v : Nat} {W : Label} (h : W ∈ hbPreds (chunked p ch) (.finish v)) :
    W = .start v ∨
    (∃ c, c < ch.members.size ∧ (p.el (ch.mem c 0)).src = some v ∧ W = sentLabel (chunked p ch) c) ∨
    (∃ c i, c < ch.members.size ∧ (p.el (ch.mem c 0)).dsts[i]? = some (some v) ∧
      W = gotLabel (chunked p ch) c i) := by
  simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range] at h
  rcases h with h | ⟨c, hc, h⟩
  · exact Or.inl h
  rw [chunked_size] at hc
  simp only [chunked_get, hc, ite_true, ecOf, List.mem_append, List.mem_filterMap, List.mem_range] at h
  rcases h with h | ⟨i, _, h⟩
  · right; left
    split at h
    · rename_i hs; simp at h; exact ⟨c, hc, hs, h⟩
    · simp at h
  · right; right
    split at h
    · rename_i hd; simp at h; exact ⟨c, i, hc, hd, h.symm⟩
    · simp at h

/-- `x` is a member's label of the chunked program's label `X`. -/
def MemOf (p : Prog) (ch : Chunking) (x X : Label) : Prop := Kinded p x ∧ up ch x = X

theorem mem_read {k c : Nat} {x : Label} (h : MemOf p ch x (.read c)) :
    ∃ k, x = .read k ∧ ch.chunk k = c ∧ k < p.elems.size := by
  obtain ⟨hk, hu⟩ := h
  cases x <;> simp [up] at hu
  rename_i k'; exact ⟨k', rfl, hu, hk⟩

theorem mem_push {c : Nat} {x : Label} (h : MemOf p ch x (.push c)) :
    ∃ k, x = .push k ∧ ch.chunk k = c ∧ k < p.elems.size ∧ (p.el k).buffered = true := by
  obtain ⟨hk, hu⟩ := h
  cases x <;> simp [up] at hu
  rename_i k'; exact ⟨k', rfl, hu, hk.1, hk.2⟩

theorem mem_pull {c i : Nat} {x : Label} (h : MemOf p ch x (.pull c i)) :
    ∃ k, x = .pull k i ∧ ch.chunk k = c ∧ k < p.elems.size ∧ (p.el k).buffered = true := by
  obtain ⟨hk, hu⟩ := h
  cases x <;> simp [up] at hu
  rename_i k' i'; obtain ⟨rfl, rfl⟩ := hu; exact ⟨k', rfl, rfl, hk.1, hk.2⟩

theorem mem_xfer {c : Nat} {x : Label} (h : MemOf p ch x (.xfer c)) :
    ∃ k, x = .xfer k ∧ ch.chunk k = c ∧ k < p.elems.size ∧ (p.el k).buffered = false := by
  obtain ⟨hk, hu⟩ := h
  cases x <;> simp [up] at hu
  rename_i k'; exact ⟨k', rfl, hu, hk.1, hk.2⟩

theorem mem_start {v : Nat} {x : Label} (h : MemOf p ch x (.start v)) : x = .start v := by
  obtain ⟨_, hu⟩ := h
  cases x <;> simp [up] at hu; subst hu; rfl

theorem mem_finish {v : Nat} {x : Label} (h : MemOf p ch x (.finish v)) : x = .finish v := by
  obtain ⟨_, hu⟩ := h
  cases x <;> simp [up] at hu; subst hu; rfl

/-- A member of a chunk's entry label is its member's entry label. -/
theorem mem_sent (hv : Valid p ch) {c : Nat} (hc : c < ch.members.size) {x : Label}
    (h : MemOf p ch x (sentLabel (chunked p ch) c)) :
    ∃ k, x = sentLabel p k ∧ ch.chunk k = c ∧ k < p.elems.size := by
  rw [sent_chunked hc] at h
  split at h
  · obtain ⟨k, rfl, hkc, hk, hb⟩ := mem_push h
    exact ⟨k, by simp [sentLabel, el_some hk, hb], hkc, hk⟩
  · obtain ⟨k, rfl, hkc, hk, hb⟩ := mem_xfer h
    exact ⟨k, by simp [sentLabel, el_some hk, hb], hkc, hk⟩

theorem mem_got (hv : Valid p ch) {c : Nat} (hc : c < ch.members.size) {i : Nat} {x : Label}
    (h : MemOf p ch x (gotLabel (chunked p ch) c i)) :
    ∃ k, x = gotLabel p k i ∧ ch.chunk k = c ∧ k < p.elems.size := by
  rw [got_chunked hc] at h
  split at h
  · obtain ⟨k, rfl, hkc, hk, hb⟩ := mem_pull h
    exact ⟨k, by simp [gotLabel, el_some hk, hb], hkc, hk⟩
  · obtain ⟨k, rfl, hkc, hk, hb⟩ := mem_xfer h
    exact ⟨k, by simp [gotLabel, el_some hk, hb], hkc, hk⟩

/-- Chunk `c`'s labels have members: its first member's. -/
theorem sent_has (hv : Valid p ch) {c : Nat} (hc : c < ch.members.size) :
    MemOf p ch (sentLabel p (ch.mem c 0)) (sentLabel (chunked p ch) c) := by
  have h0 := hv.mem c hc 0 (hv.nonempty c hc)
  rw [sent_mem hv hc (hv.nonempty c hc), sent_chunked hc]
  split <;> rename_i hb
  · exact ⟨⟨h0.2.2, hb⟩, by simp [up, h0.1]⟩
  · exact ⟨⟨h0.2.2, by simpa using hb⟩, by simp [up, h0.1]⟩

theorem got_has (hv : Valid p ch) {c : Nat} (hc : c < ch.members.size) (i : Nat) :
    MemOf p ch (gotLabel p (ch.mem c 0) i) (gotLabel (chunked p ch) c i) := by
  have h0 := hv.mem c hc 0 (hv.nonempty c hc)
  rw [got_mem hv hc (hv.nonempty c hc), got_chunked hc]
  split <;> rename_i hb
  · exact ⟨⟨h0.2.2, hb⟩, by simp [up, h0.1]⟩
  · exact ⟨⟨h0.2.2, by simpa using hb⟩, by simp [up, h0.1]⟩

/-- A chunk's own steps: its read before its entry or transfer, its entry before an arrival. -/
def IStep : Label → Label → Prop
  | .read c, .push c' => c = c'
  | .read c, .xfer c' => c = c'
  | .push c, .pull c' _ => c = c'
  | _, _ => False

/-- An edge of the chunked program's order, member by member: `W` has a member when `Z` does,
and every member of `W` comes before every member of `Z`, or, along a chunk's own step, each
member's `W` before its own `Z`. -/
def EdgeOk (p : Prog) (ch : Chunking) (W Z : Label) : Prop :=
  ((∃ z, MemOf p ch z Z) → ∃ w, MemOf p ch w W) ∧
  ((∀ w z, MemOf p ch w W → MemOf p ch z Z → HB p w z) ∨
   (IStep W Z ∧ ∀ z, MemOf p ch z Z → ∃ w, MemOf p ch w W ∧ eidx ch w = eidx ch z ∧ HB p w z))

theorem chunk_buffered (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    (p.el (ch.mem (ch.chunk k) 0)).buffered = (p.el k).buffered := (buffered_k hv hk).symm

theorem edgeOk (hv : Valid p ch) {W Z : Label} (h : W ∈ hbPreds (chunked p ch) Z) :
    EdgeOk p ch W Z := by
  cases Z with
  | start v =>
    obtain ⟨u, hu, rfl⟩ := preds_start h
    refine ⟨fun _ => ⟨.finish u, trivial, rfl⟩, Or.inl ?_⟩
    intro w z hw hz
    rw [mem_finish hw, mem_start hz]
    exact HB.single (by simp [hbPreds, hu])
  | finish v =>
    rcases preds_finish h with rfl | ⟨c, hc, hs, rfl⟩ | ⟨c, i, hc, hd, rfl⟩
    · refine ⟨fun _ => ⟨.start v, trivial, rfl⟩, Or.inl ?_⟩
      intro w z hw hz
      rw [mem_start hw, mem_finish hz]
      exact HB.single (by simp [hbPreds])
    · refine ⟨fun _ => ⟨_, sent_has hv hc⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k, rfl, hkc, hk⟩ := mem_sent hv hc hw
      rw [mem_finish hz]
      have hsk : (p.el k).src = some v := by rw [(same_k hv hk).1, hkc, hs]
      exact HB.single (mem_hbPreds_finish_sent (el_some hk) hsk)
    · refine ⟨fun _ => ⟨_, got_has hv hc i⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k, rfl, hkc, hk⟩ := mem_got hv hc hw
      rw [mem_finish hz]
      have hdk : (p.el k).dsts[i]? = some (some v) := by rw [(same_k hv hk).2.1, hkc, hd]
      exact HB.single (mem_hbPreds_finish_got (el_some hk) hdk)
  | read c =>
    obtain ⟨hc, ⟨s, hs, rfl⟩ | ⟨j, hj, rfl⟩⟩ := preds_read h
    · refine ⟨fun _ => ⟨.start s, trivial, rfl⟩, Or.inl ?_⟩
      intro w z hw hz
      rw [mem_start hw]
      obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hz
      have hsk : (p.el k).src = some s := by rw [(same_k hv hk).1, hkc, hs]
      exact HB.single (by simp [hbPreds, el_some hk, hsk, optL])
    · obtain ⟨hjs, hcj, _⟩ := prev_last hv hc hj
      refine ⟨fun _ => ⟨.read j, hjs, rfl⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k', rfl, hk'c, hk'⟩ := mem_read (k := 0) hw
      obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hz
      obtain ⟨_, hik, hmk⟩ := hv.cover k hk
      rw [hkc] at hik hmk
      have := hb_link hv hc hj (fun k => .read k) (fun k => .read k)
        (fun a b hab hb => hb_read_chain hv hcj hab hb) (edge_read hv hc hj)
        (fun b hb => hb_read_chain hv hc (Nat.zero_le b) hb) hk' hk'c hik
      rwa [hmk] at this
  | push c =>
    obtain ⟨hc, rfl | ⟨j, hj, rfl⟩⟩ := preds_push h
    · refine ⟨fun ⟨z, hz⟩ => ?_, Or.inr ⟨rfl, ?_⟩⟩
      · obtain ⟨k, rfl, hkc, hk, _⟩ := mem_push hz
        exact ⟨.read k, hk, by simp [up, hkc]⟩
      · intro z hz
        obtain ⟨k, rfl, hkc, hk, _⟩ := mem_push hz
        exact ⟨.read k, ⟨hk, by simp [up, hkc]⟩, rfl, HB.single (by simp [hbPreds, el_some hk])⟩
    · obtain ⟨hjs, hcj, _⟩ := prev_last hv hc hj
      refine ⟨fun _ => ⟨_, sent_has hv hcj⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k', rfl, hk'c, hk'⟩ := mem_sent hv hcj hw
      obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_push hz
      obtain ⟨_, hik, hmk⟩ := hv.cover k hk
      rw [hkc] at hik hmk
      have hbuf : (p.el (ch.mem c 0)).buffered = true := by rw [← hkc, chunk_buffered hv hk, hbk]
      have := hb_link hv hc hj (fun k => sentLabel p k) (fun k => .push k)
        (fun a b hab hb => hb_sent_chain hv hcj hab hb) (edge_sent hv hc hj)
        (fun b hb => hb_chain (fun k => .push k) (fun a ha => step_push hv hc ha hbuf)
          (Nat.zero_le b) hb) hk' hk'c hik
      rwa [hmk] at this
  | pull c i =>
    obtain ⟨hc, rfl | ⟨d, hd, rfl⟩ | ⟨j, hj, rfl⟩⟩ := preds_pull h
    · refine ⟨fun ⟨z, hz⟩ => ?_, Or.inr ⟨rfl, ?_⟩⟩
      · obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_pull hz
        exact ⟨.push k, ⟨hk, hbk⟩, by simp [up, hkc]⟩
      · intro z hz
        obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_pull hz
        exact ⟨.push k, ⟨⟨hk, hbk⟩, by simp [up, hkc]⟩, rfl,
          HB.single (by simp [hbPreds, el_some hk])⟩
    · refine ⟨fun _ => ⟨.start d, trivial, rfl⟩, Or.inl ?_⟩
      intro w z hw hz
      rw [mem_start hw]
      obtain ⟨k, rfl, hkc, hk, _⟩ := mem_pull hz
      have hdk : (p.el k).dsts[i]? = some (some d) := by rw [(same_k hv hk).2.1, hkc, hd]
      exact HB.single (by simp [hbPreds, el_some hk, hdk])
    · obtain ⟨hjs, hcj, _⟩ := prev_last hv hc hj
      refine ⟨fun _ => ⟨_, got_has hv hcj i⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k', rfl, hk'c, hk'⟩ := mem_got hv hcj hw
      obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_pull hz
      obtain ⟨_, hik, hmk⟩ := hv.cover k hk
      rw [hkc] at hik hmk
      have hbuf : (p.el (ch.mem c 0)).buffered = true := by rw [← hkc, chunk_buffered hv hk, hbk]
      have := hb_link hv hc hj (fun k => gotLabel p k i) (fun k => .pull k i)
        (fun a b hab hb => hb_got_chain hv hcj hab hb i) (edge_got_pull hv hc hj i)
        (fun b hb => hb_chain (fun k => .pull k i) (fun a ha => step_pull hv hc ha hbuf i)
          (Nat.zero_le b) hb) hk' hk'c hik
      rwa [hmk] at this
  | xfer c =>
    obtain ⟨hc, rfl | ⟨d, hd, rfl⟩ | ⟨j, i, hj, hi, rfl⟩⟩ := preds_xfer h
    · refine ⟨fun ⟨z, hz⟩ => ?_, Or.inr ⟨rfl, ?_⟩⟩
      · obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hz
        exact ⟨.read k, hk, by simp [up, hkc]⟩
      · intro z hz
        obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hz
        exact ⟨.read k, ⟨hk, by simp [up, hkc]⟩, rfl, HB.single (by simp [hbPreds, el_some hk])⟩
    · refine ⟨fun _ => ⟨.start d, trivial, rfl⟩, Or.inl ?_⟩
      intro w z hw hz
      rw [mem_start hw]
      obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hz
      have hdk : some d ∈ (p.el k).dsts := by rw [(same_k hv hk).2.1, hkc]; exact hd
      exact HB.single (by
        simp only [hbPreds, el_some hk, List.mem_cons, List.mem_append, List.mem_map,
          List.mem_filterMap, id]
        exact Or.inl (Or.inr ⟨d, ⟨some d, hdk, rfl⟩, rfl⟩))
    · obtain ⟨hjs, hcj, _⟩ := prev_last hv hc hj
      refine ⟨fun _ => ⟨_, got_has hv hcj i⟩, Or.inl ?_⟩
      intro w z hw hz
      obtain ⟨k', rfl, hk'c, hk'⟩ := mem_got hv hcj hw
      obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_xfer hz
      obtain ⟨_, hik, hmk⟩ := hv.cover k hk
      rw [hkc] at hik hmk
      have hbuf : (p.el (ch.mem c 0)).buffered = false := by rw [← hkc, chunk_buffered hv hk, hbk]
      have := hb_link hv hc hj (fun k => gotLabel p k i) (fun k => .xfer k)
        (fun a b hab hb => hb_got_chain hv hcj hab hb i) (edge_got_xfer hv hc hj hi)
        (fun b hb => hb_chain (fun k => .xfer k) (fun a ha => step_xfer hv hc ha hbuf)
          (Nat.zero_le b) hb) hk' hk'c hik
      rwa [hmk] at this

/-- Labels of one chunk ordered by its own steps, or one label. -/
def Internal : Label → Label → Prop
  | .read c, .read c' => c = c'
  | .read c, .push c' => c = c'
  | .read c, .pull c' _ => c = c'
  | .read c, .xfer c' => c = c'
  | .push c, .push c' => c = c'
  | .push c, .pull c' _ => c = c'
  | .pull c i, .pull c' i' => c = c' ∧ i = i'
  | .xfer c, .xfer c' => c = c'
  | _, _ => False

theorem internal_step {X W Z : Label} (h₁ : Internal X W) (h₂ : IStep W Z) : Internal X Z := by
  cases X <;> cases W <;> cases Z <;> simp_all [Internal, IStep]

/-- A chunk's members' labels of one kind follow stream order. -/
theorem hb_same (hv : Valid p ch) {X x y : Label} (hx : MemOf p ch x X) (hy : MemOf p ch y X)
    (hxy : eidx ch x ≤ eidx ch y) (hX : ∃ c, X = .read c ∨ X = .push c ∨ (∃ i, X = .pull c i) ∨ X = .xfer c) :
    HB p x y := by
  obtain ⟨c, hX⟩ := hX
  -- Both members are of chunk `c`, at their positions.
  have pos (k : Nat) (hk : k < p.elems.size) (hkc : ch.chunk k = c) :
      c < ch.members.size ∧ ch.idx k < ch.len c ∧ ch.mem c (ch.idx k) = k := by
    obtain ⟨h1, h2, h3⟩ := hv.cover k hk; rw [hkc] at h1 h2 h3; exact ⟨h1, h2, h3⟩
  rcases hX with rfl | rfl | ⟨i, rfl⟩ | rfl
  · obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hx
    obtain ⟨k', rfl, hk'c, hk'⟩ := mem_read (k := 0) hy
    obtain ⟨hc, _, hm⟩ := pos k hk hkc
    obtain ⟨_, hi', hm'⟩ := pos k' hk' hk'c
    have := hb_read_chain hv hc (by simpa [eidx, elemOf] using hxy) hi'
    rwa [hm, hm'] at this
  · obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_push hx
    obtain ⟨k', rfl, hk'c, hk', _⟩ := mem_push hy
    obtain ⟨hc, _, hm⟩ := pos k hk hkc
    obtain ⟨_, hi', hm'⟩ := pos k' hk' hk'c
    have hbuf : (p.el (ch.mem c 0)).buffered = true := by rw [← hkc, chunk_buffered hv hk, hbk]
    have := hb_chain (fun k => .push k) (fun a ha => step_push hv hc ha hbuf) (by simpa [eidx, elemOf] using hxy) hi'
    rwa [hm, hm'] at this
  · obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_pull hx
    obtain ⟨k', rfl, hk'c, hk', _⟩ := mem_pull hy
    obtain ⟨hc, _, hm⟩ := pos k hk hkc
    obtain ⟨_, hi', hm'⟩ := pos k' hk' hk'c
    have hbuf : (p.el (ch.mem c 0)).buffered = true := by rw [← hkc, chunk_buffered hv hk, hbk]
    have := hb_chain (fun k => .pull k i) (fun a ha => step_pull hv hc ha hbuf i) (by simpa [eidx, elemOf] using hxy) hi'
    rwa [hm, hm'] at this
  · obtain ⟨k, rfl, hkc, hk, hbk⟩ := mem_xfer hx
    obtain ⟨k', rfl, hk'c, hk', _⟩ := mem_xfer hy
    obtain ⟨hc, _, hm⟩ := pos k hk hkc
    obtain ⟨_, hi', hm'⟩ := pos k' hk' hk'c
    have hbuf : (p.el (ch.mem c 0)).buffered = false := by rw [← hkc, chunk_buffered hv hk, hbk]
    have := hb_chain (fun k => .xfer k) (fun a ha => step_xfer hv hc ha hbuf) (by simpa [eidx, elemOf] using hxy) hi'
    rwa [hm, hm'] at this

/-- A chunk label with a member has one at least as late in the chunk as a given member of a
label of the same chunk. -/
theorem later_member (hv : Valid p ch) {X W x w₀ : Label} (hi : Internal X W) (hx : MemOf p ch x X)
    (hw₀ : MemOf p ch w₀ W) : ∃ w, MemOf p ch w W ∧ eidx ch x ≤ eidx ch w := by
  -- The chunk, and the last member's label of `W`'s kind.
  have last (k₀ k : Nat) (hk₀ : k₀ < p.elems.size) (hk : k < p.elems.size)
      (hc : ch.chunk k = ch.chunk k₀) :
      let c := ch.chunk k₀
      let m := ch.mem c (ch.len c - 1)
      m < p.elems.size ∧ ch.chunk m = c ∧ ch.idx k ≤ ch.idx m ∧
        (p.el m).buffered = (p.el k₀).buffered := by
    obtain ⟨hc₀, hi₀, _⟩ := hv.cover k₀ hk₀
    obtain ⟨_, hik, _⟩ := hv.cover k hk
    rw [hc] at hik
    have hm := hv.mem (ch.chunk k₀) hc₀ (ch.len (ch.chunk k₀) - 1) (by omega)
    refine ⟨hm.2.2, hm.1, by rw [hm.2.1]; omega, ?_⟩
    rw [(hv.same _ hc₀ _ (by omega)).2.2, chunk_buffered hv hk₀]
  cases X <;> cases W <;> simp only [Internal] at hi
  all_goals first
    | (obtain ⟨k₀, rfl, hk₀c, hk₀⟩ := mem_read (k := 0) hw₀)
    | (obtain ⟨k₀, rfl, hk₀c, hk₀, hb₀⟩ := mem_push hw₀)
    | (obtain ⟨k₀, rfl, hk₀c, hk₀, hb₀⟩ := mem_pull hw₀)
    | (obtain ⟨k₀, rfl, hk₀c, hk₀, hb₀⟩ := mem_xfer hw₀)
  all_goals first
    | (obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hx)
    | (obtain ⟨k, rfl, hkc, hk, _⟩ := mem_push hx)
    | (obtain ⟨k, rfl, hkc, hk, _⟩ := mem_pull hx)
    | (obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hx)
  all_goals
    have hcc : ch.chunk k = ch.chunk k₀ := by simp_all
    obtain ⟨hm, hmc, hle, hbm⟩ := last k₀ k hk₀ hk hcc
  · exact ⟨.read _, ⟨hm, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.push _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.pull _ _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.xfer _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.push _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.pull _ _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.pull _ _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩
  · exact ⟨.xfer _, ⟨⟨hm, by rw [hbm, hb₀]⟩, by simp only [up]; rw [hmc, hk₀c]⟩, by simpa [eidx, elemOf] using hle⟩

/-- **Order transfers from the chunked program**: every member before every member, or along a
chunk's own steps, members in stream order. -/
theorem hb_transfer (hv : Valid p ch) {X Y : Label} (h : HB (chunked p ch) X Y) :
    (∀ x y, MemOf p ch x X → MemOf p ch y Y → HB p x y) ∨
    (Internal X Y ∧ ∀ x y, MemOf p ch x X → MemOf p ch y Y → eidx ch x ≤ eidx ch y → HB p x y) := by
  induction h with
  | refl =>
    cases X with
    | start v => left; intro x y hx hy; rw [mem_start hx, mem_start hy]; exact .refl _
    | finish v => left; intro x y hx hy; rw [mem_finish hx, mem_finish hy]; exact .refl _
    | read c => right; exact ⟨rfl, fun x y hx hy hxy => hb_same hv hx hy hxy ⟨c, Or.inl rfl⟩⟩
    | push c => right; exact ⟨rfl, fun x y hx hy hxy => hb_same hv hx hy hxy ⟨c, Or.inr (Or.inl rfl)⟩⟩
    | pull c i => right; exact ⟨⟨rfl, rfl⟩, fun x y hx hy hxy =>
        hb_same hv hx hy hxy ⟨c, Or.inr (Or.inr (Or.inl ⟨i, rfl⟩))⟩⟩
    | xfer c => right; exact ⟨rfl, fun x y hx hy hxy =>
        hb_same hv hx hy hxy ⟨c, Or.inr (Or.inr (Or.inr rfl))⟩⟩
  | @step W Z _ hw ih =>
    obtain ⟨hex, hall | ⟨hst, hone⟩⟩ := edgeOk hv hw
    · left
      intro x z hx hz
      obtain ⟨w, hwm⟩ := hex ⟨z, hz⟩
      rcases ih with ih | ⟨hi, ih⟩
      · exact (ih x w hx hwm).trans (hall w z hwm hz)
      · obtain ⟨w', hw', hle⟩ := later_member hv hi hx hwm
        exact (ih x w' hx hw' hle).trans (hall w' z hw' hz)
    · rcases ih with ih | ⟨hi, ih⟩
      · left
        intro x z hx hz
        obtain ⟨w, hwm, _, hwz⟩ := hone z hz
        exact (ih x w hx hwm).trans hwz
      · right
        refine ⟨internal_step hi hst, ?_⟩
        intro x z hx hz hle
        obtain ⟨w, hwm, heq, hwz⟩ := hone z hz
        exact (ih x w hx hwm (by omega)).trans hwz

/-! ### Race-freedom transfers -/

/-- The chunk condition: two labels of one chunk along its own steps (its read before its entry,
arrival or transfer, its entry before an arrival), of a later member before an earlier one, do not
conflict. The chunked program orders them, the element program does not. -/
def CondOk (p : Prog) (ch : Chunking) (fp : LFp) (S : Label → Prop) : Prop :=
  ∀ x y, S x → S y → Kinded p x → Kinded p y → Internal (up ch x) (up ch y) → up ch x ≠ up ch y →
    eidx ch y < eidx ch x → ¬ LConflict fp x y

theorem element_label {x : Label} (hx : Kinded p x) (h : ∀ v, x ≠ .start v) (h' : ∀ v, x ≠ .finish v) :
    ∃ c, up ch x = .read c ∨ up ch x = .push c ∨ (∃ i, up ch x = .pull c i) ∨ up ch x = .xfer c := by
  cases x with
  | start v => exact absurd rfl (h v)
  | finish v => exact absurd rfl (h' v)
  | read k => exact ⟨_, Or.inl rfl⟩
  | push k => exact ⟨_, Or.inr (Or.inl rfl)⟩
  | pull k i => exact ⟨_, Or.inr (Or.inr (Or.inl ⟨i, rfl⟩))⟩
  | xfer k => exact ⟨_, Or.inr (Or.inr (Or.inr rfl))⟩

/-- **Race-freedom transfers from the chunked program**, whose labels' footprints contain their
members', when the chunk condition holds. -/
theorem raceFree_of_chunked (hv : Valid p ch) {fp fpc : LFp} {S Sc : Label → Prop}
    (hcond : CondOk p ch fp S) (hcov : ∀ x, Kinded p x → ∀ a ∈ fp x, a ∈ fpc (up ch x))
    (hS : ∀ x, S x → Kinded p x ∧ Sc (up ch x)) (h : RaceFree (chunked p ch) fpc Sc) :
    RaceFree p fp S := by
  intro x y hx hy hne hc
  obtain ⟨hkx, hsx⟩ := hS x hx
  obtain ⟨hky, hsy⟩ := hS y hy
  have mx : MemOf p ch x (up ch x) := ⟨hkx, rfl⟩
  have my : MemOf p ch y (up ch y) := ⟨hky, rfl⟩
  by_cases hup : up ch x = up ch y
  · -- Members of one label: stream order.
    rw [← hup] at my
    by_cases hev : (∃ v, x = .start v) ∨ (∃ v, x = .finish v)
    · rcases hev with ⟨v, rfl⟩ | ⟨v, rfl⟩
      · exact absurd (mem_start my).symm hne
      · exact absurd (mem_finish my).symm hne
    · simp only [not_or, not_exists] at hev
      have hX := element_label (ch := ch) hkx hev.1 hev.2
      rcases Nat.le_total (eidx ch x) (eidx ch y) with hle | hle
      · exact Or.inl (hb_same hv mx my hle hX)
      · exact Or.inr (hb_same hv my mx hle hX)
  · obtain ⟨a, ha, b, hb, hab⟩ := hc
    have hcc : LConflict fpc (up ch x) (up ch y) := ⟨a, hcov x hkx a ha, b, hcov y hky b hb, hab⟩
    rcases h _ _ hsx hsy hup hcc with hxy | hyx
    · rcases hb_transfer hv hxy with hall | ⟨hi, hmono⟩
      · exact Or.inl (hall x y mx my)
      · rcases Nat.lt_or_ge (eidx ch y) (eidx ch x) with hlt | hge
        · exact absurd ⟨a, ha, b, hb, hab⟩ (hcond x y hx hy hkx hky hi hup hlt)
        · exact Or.inl (hmono x y mx my hge)
    · rcases hb_transfer hv hyx with hall | ⟨hi, hmono⟩
      · exact Or.inr (hall y x my mx)
      · rcases Nat.lt_or_ge (eidx ch x) (eidx ch y) with hlt | hge
        · exact absurd (LConflict.symm ⟨a, ha, b, hb, hab⟩) (hcond y x hy hx hky hkx hi (Ne.symm hup) hlt)
        · exact Or.inr (hmono y x my mx hge)

/-! ### Completion: the chunked program's runs, member by member -/

theorem chunked_el {c : Nat} (hc : c < ch.members.size) : (chunked p ch).el c = ecOf p ch c := by
  simp [Prog.el, chunked, hc, ecOf]

/-- Member `a` of a chunked label: the label of the same kind of the chunk's member `a`. -/
def memL (ch : Chunking) : Label → Nat → Label
  | .start v, _ => .start v
  | .finish v, _ => .finish v
  | .read c, a => .read (ch.mem c a)
  | .push c, a => .push (ch.mem c a)
  | .pull c i, a => .pull (ch.mem c a) i
  | .xfer c, a => .xfer (ch.mem c a)

/-- How many members a chunked label has to fire: a chunk's, or one. -/
def width (ch : Chunking) : Label → Nat
  | .start _ | .finish _ => 1
  | .read c | .push c | .pull c _ | .xfer c => ch.len c

/-- What fired in the chunked program (`Fc`) and in the element program (`F`) agree, while the
members of `X` before `n` have fired too. -/
structure Sim (p : Prog) (ch : Chunking) (Fc : List Label) (X : Label) (n : Nat) (F : List Label) :
    Prop where
  fwd : ∀ x ∈ F, Kinded p x ∧ (up ch x ∈ Fc ∨ (up ch x = X ∧ eidx ch x < n))
  bwd : ∀ Y ∈ Fc, ∀ x, MemOf p ch x Y → x ∈ F
  part : ∀ x, MemOf p ch x X → eidx ch x < n → x ∈ F
  kc : ∀ Y ∈ Fc, Kinded (chunked p ch) Y

theorem mem_of_kinded (hv : Valid p ch) {k : Nat} (hk : k < p.elems.size) :
    ch.chunk k < ch.members.size ∧ ch.idx k < ch.len (ch.chunk k) ∧ ch.mem (ch.chunk k) (ch.idx k) = k :=
  hv.cover k hk

/-- A fired chunk label's members, of either kind of entry or arrival, have fired. -/
theorem sent_of (hv : Valid p ch) {Fc F : List Label} {X : Label} {n : Nat}
    (hs : Sim p ch Fc X n F) {k : Nat} (hk : k < p.elems.size) (h : Sent Fc (ch.chunk k)) :
    Sent F k := by
  obtain ⟨hc, _, _⟩ := mem_of_kinded hv hk
  rcases h with h | h
  · have hkc := hs.kc _ h
    simp only [Kinded, chunked_el hc, ecOf] at hkc
    have hb : (p.el k).buffered = true := by rw [← chunk_buffered hv hk]; exact hkc.2
    exact Or.inl (hs.bwd _ h _ ⟨⟨hk, hb⟩, rfl⟩)
  · have hkc := hs.kc _ h
    simp only [Kinded, chunked_el hc, ecOf] at hkc
    have hb : (p.el k).buffered = false := by rw [← chunk_buffered hv hk]; exact hkc.2
    exact Or.inr (hs.bwd _ h _ ⟨⟨hk, hb⟩, rfl⟩)

theorem got_of (hv : Valid p ch) {Fc F : List Label} {X : Label} {n : Nat}
    (hs : Sim p ch Fc X n F) {k i : Nat} (hk : k < p.elems.size) (h : Got Fc (ch.chunk k) i) :
    Got F k i := by
  obtain ⟨hc, _, _⟩ := mem_of_kinded hv hk
  rcases h with h | h
  · have hkc := hs.kc _ h
    simp only [Kinded, chunked_el hc, ecOf] at hkc
    have hb : (p.el k).buffered = true := by rw [← chunk_buffered hv hk]; exact hkc.2
    exact Or.inl (hs.bwd _ h _ ⟨⟨hk, hb⟩, rfl⟩)
  · have hkc := hs.kc _ h
    simp only [Kinded, chunked_el hc, ecOf] at hkc
    have hb : (p.el k).buffered = false := by rw [← chunk_buffered hv hk]; exact hkc.2
    exact Or.inr (hs.bwd _ h _ ⟨⟨hk, hb⟩, rfl⟩)

/-- Member `n` of a chunk `c`'s label: which element, and its position. -/
theorem memL_elem (hv : Valid p ch) {c n : Nat} (hc : c < ch.members.size) (hn : n < ch.len c) :
    ch.mem c n < p.elems.size ∧ ch.chunk (ch.mem c n) = c ∧ ch.idx (ch.mem c n) = n :=
  let h := hv.mem c hc n hn; ⟨h.2.2, h.1, h.2.1⟩

/-- The previous member's labels, for member `n + 1`. -/
theorem prev_succ (hv : Valid p ch) {c n : Nat} (hc : c < ch.members.size) (hn : n + 1 < ch.len c) :
    (p.el (ch.mem c (n + 1))).prev = some (ch.mem c n) := hv.prev c hc n hn

/-- **Each member fires in turn**: while a chunked label `X` that may fire is expanded, its member
`n` may fire, and has not. -/
theorem fire_member (hv : Valid p ch) {Fc F : List Label} {X : Label} {n : Nat}
    (hs : Sim p ch Fc X n F) (he : En (chunked p ch) Fc X) (hX : X ∉ Fc) (hn : n < width ch X) :
    En p F (memL ch X n) ∧ memL ch X n ∉ F := by
  -- Not fired: its chunked label has not, and it is member `n`.
  have notin (x : Label) (hux : up ch x = X) (hex : eidx ch x = n) : x ∉ F := by
    intro hx
    rcases (hs.fwd x hx).2 with h | ⟨_, h⟩
    · exact hX (hux ▸ h)
    · omega
  cases X with
  | start v =>
    obtain ⟨hv', hpre⟩ := he
    refine ⟨⟨hv', fun u hu => hs.bwd _ (hpre u hu) _ ⟨trivial, rfl⟩⟩, ?_⟩
    simp only [width] at hn
    exact notin _ rfl (by simp only [eidx, elemOf, memL]; omega)
  | finish v =>
    obtain ⟨hv', hst, hall⟩ := he
    refine ⟨⟨hv', hs.bwd _ hst _ ⟨trivial, rfl⟩, fun k e hk => ?_⟩, ?_⟩
    · have hks : k < p.elems.size := (Array.getElem?_eq_some_iff.mp hk).1
      have hek : e = p.el k := by rw [el_some hks] at hk; exact (Option.some.inj hk).symm
      subst hek
      obtain ⟨hc, _, _⟩ := mem_of_kinded hv hks
      have := hall (ch.chunk k) (ecOf p ch (ch.chunk k)) (by rw [chunked_get]; simp [hc])
      obtain ⟨hsrc, hdst⟩ := same_k hv hks
      refine ⟨fun hsv => sent_of hv hs hks (this.1 (by simp only [ecOf]; rw [← hsrc]; exact hsv)),
        fun i hi => got_of hv hs hks (this.2 i (by simp only [ecOf]; rw [← hdst.1]; exact hi))⟩
    · simp only [width] at hn
      exact notin _ rfl (by simp only [eidx, elemOf, memL]; omega)
  | read c =>
    obtain ⟨ec, hec, ⟨s', hs', hst⟩, hpre⟩ := he
    have hc : c < ch.members.size := by
      rw [chunked_get] at hec; split at hec
      · assumption
      · simp at hec
    have hece : ec = ecOf p ch c := by rw [chunked_get, ite_cond_eq_true _ _ (eq_true hc)] at hec; exact (Option.some.inj hec).symm
    subst hece
    simp only [width] at hn
    obtain ⟨hk, hkc, hki⟩ := memL_elem hv hc hn
    refine ⟨⟨p.el (ch.mem c n), el_some hk, ⟨s', ?_, hs.bwd _ hst _ ⟨trivial, rfl⟩⟩, fun j hj => ?_⟩,
      notin _ (by simp [up, memL, hkc]) (by simp [eidx, elemOf, memL, hki])⟩
    · rw [(same_k hv hk).1, hkc]; exact hs'
    · cases n with
      | zero =>
        have hjc := hpre (ch.chunk j) (by simp [ecOf, hj])
        exact hs.bwd _ hjc _ ⟨(hv.first c hc j hj).1, rfl⟩
      | succ n =>
        rw [prev_succ hv hc hn] at hj
        cases hj
        obtain ⟨hk', hk'c, hk'i⟩ := memL_elem hv hc (show n < ch.len c by omega)
        exact hs.part _ ⟨hk', by simp [up, hk'c]⟩ (by simp [eidx, elemOf, hk'i])
  | push c =>
    obtain ⟨ec, hec, hbuf, hrd, hpre⟩ := he
    have hc : c < ch.members.size := by
      rw [chunked_get] at hec; split at hec
      · assumption
      · simp at hec
    have hece : ec = ecOf p ch c := by rw [chunked_get, ite_cond_eq_true _ _ (eq_true hc)] at hec; exact (Option.some.inj hec).symm
    subst hece
    simp only [width] at hn
    obtain ⟨hk, hkc, hki⟩ := memL_elem hv hc hn
    have hbk : (p.el (ch.mem c n)).buffered = true := by
      rw [buffered_k hv hk, hkc]; exact hbuf
    refine ⟨⟨p.el (ch.mem c n), el_some hk, hbk, hs.bwd _ hrd _ ⟨hk, by simp [up, hkc]⟩, fun j hj => ?_⟩,
      notin _ (by simp [up, memL, hkc]) (by simp [eidx, elemOf, memL, hki])⟩
    cases n with
    | zero =>
      have hjs := (hv.first c hc j hj).1
      exact sent_of hv hs hjs (hpre (ch.chunk j) (by simp [ecOf, hj]))
    | succ n =>
      rw [prev_succ hv hc hn] at hj
      cases hj
      obtain ⟨hk', hk'c, hk'i⟩ := memL_elem hv hc (show n < ch.len c by omega)
      have hbk' : (p.el (ch.mem c n)).buffered = true := by rw [buffered_k hv hk', hk'c]; exact hbuf
      exact Or.inl (hs.part _ ⟨⟨hk', hbk'⟩, by simp [up, hk'c]⟩ (by simp [eidx, elemOf, hk'i]))
  | pull c i =>
    obtain ⟨ec, hec, hbuf, ⟨d, hd, hsd⟩, hpu, hpre⟩ := he
    have hc : c < ch.members.size := by
      rw [chunked_get] at hec; split at hec
      · assumption
      · simp at hec
    have hece : ec = ecOf p ch c := by rw [chunked_get, ite_cond_eq_true _ _ (eq_true hc)] at hec; exact (Option.some.inj hec).symm
    subst hece
    simp only [width] at hn
    obtain ⟨hk, hkc, hki⟩ := memL_elem hv hc hn
    have hbk : (p.el (ch.mem c n)).buffered = true := by
      rw [buffered_k hv hk, hkc]; exact hbuf
    refine ⟨⟨p.el (ch.mem c n), el_some hk, hbk, ⟨d, ?_, hs.bwd _ hsd _ ⟨trivial, rfl⟩⟩,
      hs.bwd _ hpu _ ⟨⟨hk, hbk⟩, by simp [up, hkc]⟩, fun j hj => ?_⟩,
      notin _ (by simp [up, memL, hkc]) (by simp [eidx, elemOf, memL, hki])⟩
    · rw [(same_k hv hk).2.1, hkc]; exact hd
    · cases n with
      | zero =>
        have hjs := (hv.first c hc j hj).1
        exact got_of hv hs hjs (hpre (ch.chunk j) (by simp [ecOf, hj]))
      | succ n =>
        rw [prev_succ hv hc hn] at hj
        cases hj
        obtain ⟨hk', hk'c, hk'i⟩ := memL_elem hv hc (show n < ch.len c by omega)
        have hbk' : (p.el (ch.mem c n)).buffered = true := by rw [buffered_k hv hk', hk'c]; exact hbuf
        exact Or.inl (hs.part _ ⟨⟨hk', hbk'⟩, by simp [up, hk'c]⟩ (by simp [eidx, elemOf, hk'i]))
  | xfer c =>
    obtain ⟨ec, hec, hbuf, hrd, ⟨hne, hall⟩, hpre⟩ := he
    have hc : c < ch.members.size := by
      rw [chunked_get] at hec; split at hec
      · assumption
      · simp at hec
    have hece : ec = ecOf p ch c := by rw [chunked_get, ite_cond_eq_true _ _ (eq_true hc)] at hec; exact (Option.some.inj hec).symm
    subst hece
    simp only [width] at hn
    obtain ⟨hk, hkc, hki⟩ := memL_elem hv hc hn
    have hbk : (p.el (ch.mem c n)).buffered = false := by
      rw [buffered_k hv hk, hkc]; exact hbuf
    have hdk : (p.el (ch.mem c n)).dsts = (p.el (ch.mem c 0)).dsts := by
      rw [(same_k hv hk).2.1, hkc]
    refine ⟨⟨p.el (ch.mem c n), el_some hk, hbk, hs.bwd _ hrd _ ⟨hk, by simp [up, hkc]⟩,
      ⟨by rw [hdk]; exact hne, fun o ho => ?_⟩, fun j hj i hi => ?_⟩,
      notin _ (by simp [up, memL, hkc]) (by simp [eidx, elemOf, memL, hki])⟩
    · obtain ⟨d, rfl, hsd⟩ := hall o (by rw [hdk] at ho; exact ho)
      exact ⟨d, rfl, hs.bwd _ hsd _ ⟨trivial, rfl⟩⟩
    · cases n with
      | zero =>
        have hjs := (hv.first c hc j hj).1
        exact got_of hv hs hjs (hpre (ch.chunk j) (by simp [ecOf, hj]) i
          (by simpa [ecOf] using hi))
      | succ n =>
        rw [prev_succ hv hc hn] at hj
        cases hj
        obtain ⟨hk', hk'c, hk'i⟩ := memL_elem hv hc (show n < ch.len c by omega)
        have hbk' : (p.el (ch.mem c n)).buffered = false := by rw [buffered_k hv hk', hk'c]; exact hbuf
        exact Or.inr (hs.part _ ⟨⟨hk', hbk'⟩, by simp [up, hk'c]⟩ (by simp [eidx, elemOf, hk'i]))

theorem member_eq (hv : Valid p ch) {X x : Label} (hx : MemOf p ch x X) :
    x = memL ch X (eidx ch x) := by
  cases X with
  | start v => rw [mem_start hx]; rfl
  | finish v => rw [mem_finish hx]; rfl
  | read c =>
    obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hx
    simp only [memL, eidx, elemOf]; rw [← hkc, mem_idx hv hk]
  | push c =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_push hx
    simp only [memL, eidx, elemOf]; rw [← hkc, mem_idx hv hk]
  | pull c i =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_pull hx
    simp only [memL, eidx, elemOf]; rw [← hkc, mem_idx hv hk]
  | xfer c =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hx
    simp only [memL, eidx, elemOf]; rw [← hkc, mem_idx hv hk]

theorem eidx_lt (hv : Valid p ch) {X x : Label} (hx : MemOf p ch x X) : eidx ch x < width ch X := by
  cases X with
  | start v => rw [mem_start hx]; simp [eidx, elemOf, width]
  | finish v => rw [mem_finish hx]; simp [eidx, elemOf, width]
  | read c =>
    obtain ⟨k, rfl, hkc, hk⟩ := mem_read (k := 0) hx
    simp only [eidx, elemOf, width]; rw [← hkc]; exact (hv.cover k hk).2.1
  | push c =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_push hx
    simp only [eidx, elemOf, width]; rw [← hkc]; exact (hv.cover k hk).2.1
  | pull c i =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_pull hx
    simp only [eidx, elemOf, width]; rw [← hkc]; exact (hv.cover k hk).2.1
  | xfer c =>
    obtain ⟨k, rfl, hkc, hk, _⟩ := mem_xfer hx
    simp only [eidx, elemOf, width]; rw [← hkc]; exact (hv.cover k hk).2.1

/-- A label of the chunked program that may fire is of its kind. -/
theorem kinded_of_en {Fc : List Label} {X : Label} (he : En (chunked p ch) Fc X) :
    Kinded (chunked p ch) X := by
  have lt (c : Nat) (ec : Elem) (h : (chunked p ch).elems[c]? = some ec) :
      c < (chunked p ch).elems.size ∧ (chunked p ch).el c = ec := by
    obtain ⟨hlt, heq⟩ := Array.getElem?_eq_some_iff.mp h
    exact ⟨hlt, by simp [Prog.el, getElem!_pos (chunked p ch).elems c hlt, heq]⟩
  cases X with
  | start v => trivial
  | finish v => trivial
  | read c => obtain ⟨ec, hec, _⟩ := he; exact (lt c ec hec).1
  | push c => obtain ⟨ec, hec, hb, _⟩ := he; exact ⟨(lt c ec hec).1, by rw [(lt c ec hec).2]; exact hb⟩
  | pull c i => obtain ⟨ec, hec, hb, _⟩ := he; exact ⟨(lt c ec hec).1, by rw [(lt c ec hec).2]; exact hb⟩
  | xfer c => obtain ⟨ec, hec, hb, _⟩ := he; exact ⟨(lt c ec hec).1, by rw [(lt c ec hec).2]; exact hb⟩

/-- Member `n` of a label of its kind is a member, at position `n`. -/
theorem memL_mem (hv : Valid p ch) {X : Label} (hk : Kinded (chunked p ch) X) {n : Nat}
    (hn : n < width ch X) : MemOf p ch (memL ch X n) X := by
  cases X with
  | start v => exact ⟨trivial, rfl⟩
  | finish v => exact ⟨trivial, rfl⟩
  | read c =>
    have hc : c < ch.members.size := by simpa [Kinded, chunked_size] using hk
    obtain ⟨hm, hmc, _⟩ := memL_elem hv hc hn
    exact ⟨hm, by simp [up, memL, hmc]⟩
  | push c =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    obtain ⟨hm, hmc, _⟩ := memL_elem hv hc hn
    have hb := hk.2; rw [chunked_el hc] at hb
    exact ⟨⟨hm, by rw [buffered_k hv hm, hmc]; exact hb⟩, by simp [up, memL, hmc]⟩
  | pull c i =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    obtain ⟨hm, hmc, _⟩ := memL_elem hv hc hn
    have hb := hk.2; rw [chunked_el hc] at hb
    exact ⟨⟨hm, by rw [buffered_k hv hm, hmc]; exact hb⟩, by simp [up, memL, hmc]⟩
  | xfer c =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    obtain ⟨hm, hmc, _⟩ := memL_elem hv hc hn
    have hb := hk.2; rw [chunked_el hc] at hb
    exact ⟨⟨hm, by rw [buffered_k hv hm, hmc]; exact hb⟩, by simp [up, memL, hmc]⟩

theorem eidx_memL (hv : Valid p ch) {X : Label} (hk : Kinded (chunked p ch) X) {n : Nat}
    (hn : n < width ch X) : eidx ch (memL ch X n) = n := by
  cases X with
  | start v => simp only [width] at hn; simp [memL, eidx, elemOf]; omega
  | finish v => simp only [width] at hn; simp [memL, eidx, elemOf]; omega
  | read c =>
    have hc : c < ch.members.size := by simpa [Kinded, chunked_size] using hk
    simp [memL, eidx, elemOf, (memL_elem hv hc hn).2.2]
  | push c =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    simp [memL, eidx, elemOf, (memL_elem hv hc hn).2.2]
  | pull c i =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    simp [memL, eidx, elemOf, (memL_elem hv hc hn).2.2]
  | xfer c =>
    have hc : c < ch.members.size := by simpa [chunked_size] using hk.1
    simp [memL, eidx, elemOf, (memL_elem hv hc hn).2.2]

/-- A chunked label's members' labels, in stream order. -/
def expandL (ch : Chunking) (X : Label) : List Label := (List.range (width ch X)).map (memL ch X)

/-- Firing a chunked label: its members, in stream order. -/
theorem expand_label (hv : Valid p ch) {Fc F t : List Label} {X Y : Label}
    (hs : Sim p ch Fc Y 0 F) (hr : Run p [] t F) (he : En (chunked p ch) Fc X) (hX : X ∉ Fc) :
    ∃ F', Run p [] (t ++ expandL ch X) F' ∧ Sim p ch (X :: Fc) Y 0 F' := by
  have hkX := kinded_of_en he
  have start : Sim p ch Fc X 0 F :=
    ⟨fun x hx => ⟨(hs.fwd x hx).1, Or.inl (by
        rcases (hs.fwd x hx).2 with h | ⟨_, h⟩
        · exact h
        · omega)⟩,
     hs.bwd, fun _ _ h => absurd h (Nat.not_lt_zero _), hs.kc⟩
  have grow : ∀ n, n ≤ width ch X →
      ∃ F', Run p [] (t ++ (List.range n).map (memL ch X)) F' ∧ Sim p ch Fc X n F' := by
    intro n
    induction n with
    | zero => exact fun _ => ⟨F, by simpa using hr, start⟩
    | succ n ih =>
      intro hn
      obtain ⟨F', hr', hs'⟩ := ih (by omega)
      obtain ⟨hen, hnot⟩ := fire_member hv hs' he hX (by omega)
      have hm := memL_mem hv hkX (show n < width ch X by omega)
      refine ⟨_, by rw [List.range_succ, List.map_append, ← List.append_assoc]; exact hr'.append hen hnot,
        ⟨?_, ?_, ?_, hs'.kc⟩⟩
      · intro x hx
        rcases List.mem_cons.mp hx with rfl | hx
        · refine ⟨hm.1, Or.inr ⟨hm.2, ?_⟩⟩
          have := eidx_memL hv hkX (show n < width ch X by omega)
          omega
        · obtain ⟨hk, h⟩ := hs'.fwd x hx
          exact ⟨hk, h.imp_right fun ⟨h1, h2⟩ => ⟨h1, by omega⟩⟩
      · exact fun Z hZ x hx => List.mem_cons_of_mem _ (hs'.bwd Z hZ x hx)
      · intro x hx hlt
        rcases Nat.lt_or_ge (eidx ch x) n with h | h
        · exact List.mem_cons_of_mem _ (hs'.part x hx h)
        · have : eidx ch x = n := by omega
          rw [member_eq hv hx, this]; exact List.mem_cons_self ..
  obtain ⟨F', hr', hs'⟩ := grow (width ch X) (Nat.le_refl _)
  refine ⟨F', hr', ⟨?_, ?_, fun _ _ h => absurd h (Nat.not_lt_zero _), ?_⟩⟩
  · intro x hx
    obtain ⟨hk, h⟩ := hs'.fwd x hx
    rcases h with h | ⟨h, _⟩
    · exact ⟨hk, Or.inl (List.mem_cons_of_mem _ h)⟩
    · exact ⟨hk, Or.inl (h ▸ List.mem_cons_self ..)⟩
  · intro Z hZ x hx
    rcases List.mem_cons.mp hZ with rfl | hZ
    · exact hs'.part x hx (eidx_lt hv hx)
    · exact hs'.bwd Z hZ x hx
  · intro Z hZ
    rcases List.mem_cons.mp hZ with rfl | hZ
    · exact hkX
    · exact hs'.kc Z hZ

/-- **A complete execution of the chunked program gives one of the element program**: each
chunked label's members, in stream order (`expandL`). -/
theorem expand_run (hv : Valid p ch) {tc Gc : List Label}
    (hr : Run (chunked p ch) [] tc Gc) (hd : Done (chunked p ch) Gc) :
    ∃ G, Run p [] (tc.flatMap (expandL ch)) G ∧ Done p G := by
  have go : ∀ {Fc tc Gc}, Run (chunked p ch) Fc tc Gc → ∀ t F, Run p [] t F →
      Sim p ch Fc (.start 0) 0 F → ∃ G, Run p [] (t ++ tc.flatMap (expandL ch)) G ∧
        Sim p ch Gc (.start 0) 0 G := by
    intro Fc tc Gc r
    induction r with
    | nil => exact fun t F hr hs => ⟨F, by simpa using hr, hs⟩
    | cons he hn _ ih =>
      intro t F hr hs
      obtain ⟨F', hr', hs'⟩ := expand_label hv hs hr he hn
      obtain ⟨G, hrG, hsG⟩ := ih _ F' hr' hs'
      exact ⟨G, by simpa [List.flatMap_cons, List.append_assoc] using hrG, hsG⟩
  obtain ⟨G, hr', hs⟩ := go hr [] [] (.nil _)
    ⟨fun _ h => absurd h (List.not_mem_nil), fun _ h => absurd h (List.not_mem_nil),
     fun _ _ h => absurd h (Nat.not_lt_zero _), fun _ h => absurd h (List.not_mem_nil)⟩
  exact ⟨G, by simpa using hr', fun v hv' => hs.bwd _ (hd v (by simpa [chunked] using hv')) _ ⟨trivial, rfl⟩⟩

theorem completes_of_chunked (hv : Valid p ch) {tc Gc : List Label}
    (hr : Run (chunked p ch) [] tc Gc) (hd : Done (chunked p ch) Gc) :
    ∃ t G, Run p [] t G ∧ Done p G :=
  let ⟨G, r, d⟩ := expand_run hv hr hd; ⟨_, G, r, d⟩

/-! ### Completion: the element program's runs, chunk by chunk -/

/-- Every member of `X` has fired. -/
def AllIn (p : Prog) (ch : Chunking) (X : Label) (F : List Label) : Prop := ∀ x, MemOf p ch x X → x ∈ F

/-- A label that may fire is of its kind. -/
theorem kinded_of_enP {F : List Label} {x : Label} (he : En p F x) : Kinded p x := by
  have lt (k : Nat) (e : Elem) (h : p.elems[k]? = some e) : k < p.elems.size ∧ p.el k = e := by
    obtain ⟨hlt, heq⟩ := Array.getElem?_eq_some_iff.mp h
    exact ⟨hlt, by simp [Prog.el, getElem!_pos p.elems k hlt, heq]⟩
  cases x with
  | start v => trivial
  | finish v => trivial
  | read k => obtain ⟨e, he, _⟩ := he; exact (lt k e he).1
  | push k => obtain ⟨e, he, hb, _⟩ := he; exact ⟨(lt k e he).1, by rw [(lt k e he).2]; exact hb⟩
  | pull k i => obtain ⟨e, he, hb, _⟩ := he; exact ⟨(lt k e he).1, by rw [(lt k e he).2]; exact hb⟩
  | xfer k => obtain ⟨e, he, hb, _⟩ := he; exact ⟨(lt k e he).1, by rw [(lt k e he).2]; exact hb⟩

theorem kinded_up (hv : Valid p ch) {x : Label} (hx : Kinded p x) : Kinded (chunked p ch) (up ch x) := by
  cases x with
  | start v => trivial
  | finish v => trivial
  | read k => simpa [up, Kinded, chunked_size] using (hv.cover k hx).1
  | push k =>
    have hc := (hv.cover k hx.1).1
    exact ⟨by simpa [chunked_size] using hc, by rw [chunked_el hc]; simp [ecOf, chunk_buffered hv hx.1, hx.2]⟩
  | pull k i =>
    have hc := (hv.cover k hx.1).1
    exact ⟨by simpa [chunked_size] using hc, by rw [chunked_el hc]; simp [ecOf, chunk_buffered hv hx.1, hx.2]⟩
  | xfer k =>
    have hc := (hv.cover k hx.1).1
    exact ⟨by simpa [chunked_size] using hc, by rw [chunked_el hc]; simp [ecOf, chunk_buffered hv hx.1, hx.2]⟩

/-- When a label's last member has fired, all have (they fire in stream order). -/
theorem allIn_of_last (hv : Valid p ch) {F : List Label} (hi : Inv p F) {X : Label}
    (hk : Kinded (chunked p ch) X) (hl : memL ch X (width ch X - 1) ∈ F) : AllIn p ch X F := by
  intro x hx
  have hw : 0 < width ch X := Nat.lt_of_le_of_lt (Nat.zero_le _) (eidx_lt hv hx)
  have hm := memL_mem hv hk (show width ch X - 1 < width ch X by omega)
  have hle : eidx ch x ≤ eidx ch (memL ch X (width ch X - 1)) := by
    rw [eidx_memL hv hk (by omega)]; have := eidx_lt hv hx; omega
  cases X with
  | start v => rw [mem_start hx]; exact hl
  | finish v => rw [mem_finish hx]; exact hl
  | read c => exact HB.fired hi (hb_same hv hx hm hle ⟨c, Or.inl rfl⟩) hl
  | push c => exact HB.fired hi (hb_same hv hx hm hle ⟨c, Or.inr (Or.inl rfl)⟩) hl
  | pull c i => exact HB.fired hi (hb_same hv hx hm hle ⟨c, Or.inr (Or.inr (Or.inl ⟨i, rfl⟩))⟩) hl
  | xfer c => exact HB.fired hi (hb_same hv hx hm hle ⟨c, Or.inr (Or.inr (Or.inr rfl))⟩) hl


/-- The chunked program fired what has all its members fired. -/
def Agree (p : Prog) (ch : Chunking) (Fc F : List Label) : Prop :=
  ∀ X, X ∈ Fc ↔ Kinded (chunked p ch) X ∧ AllIn p ch X F

theorem width_pos (hv : Valid p ch) {X : Label} (hk : Kinded (chunked p ch) X) : 0 < width ch X := by
  cases X with
  | start v => simp [width]
  | finish v => simp [width]
  | read c => exact hv.nonempty c (by simpa [Kinded, chunked_size] using hk)
  | push c => exact hv.nonempty c (by simpa [chunked_size] using hk.1)
  | pull c i => exact hv.nonempty c (by simpa [chunked_size] using hk.1)
  | xfer c => exact hv.nonempty c (by simpa [chunked_size] using hk.1)

/-- A chunk's last member's entry has fired: so has the chunk's. -/
theorem sent_fc (hv : Valid p ch) {Fc F : List Label} (hi : Inv p F) (ha : Agree p ch Fc F) {c : Nat}
    (hc : c < ch.members.size) (h : Sent F (ch.mem c (ch.len c - 1))) : Sent Fc c := by
  have hn := hv.nonempty c hc
  obtain ⟨hm, hmc, hmi⟩ := memL_elem hv hc (show ch.len c - 1 < ch.len c by omega)
  rcases h with h | h
  · have hk := kinded_of_enP (hi _ h)
    have hX : Kinded (chunked p ch) (.push c) := by
      have := kinded_up hv (x := .push _) hk; simpa [up, hmc] using this
    exact Or.inl ((ha _).mpr ⟨hX, allIn_of_last hv hi hX (by simpa [memL, width] using h)⟩)
  · have hk := kinded_of_enP (hi _ h)
    have hX : Kinded (chunked p ch) (.xfer c) := by
      have := kinded_up hv (x := .xfer _) hk; simpa [up, hmc] using this
    exact Or.inr ((ha _).mpr ⟨hX, allIn_of_last hv hi hX (by simpa [memL, width] using h)⟩)

theorem got_fc (hv : Valid p ch) {Fc F : List Label} (hi : Inv p F) (ha : Agree p ch Fc F) {c i : Nat}
    (hc : c < ch.members.size) (h : Got F (ch.mem c (ch.len c - 1)) i) : Got Fc c i := by
  have hn := hv.nonempty c hc
  obtain ⟨hm, hmc, hmi⟩ := memL_elem hv hc (show ch.len c - 1 < ch.len c by omega)
  rcases h with h | h
  · have hk := kinded_of_enP (hi _ h)
    have hX : Kinded (chunked p ch) (.pull c i) := by
      have := kinded_up hv (x := .pull _ i) hk; simpa [up, hmc] using this
    exact Or.inl ((ha _).mpr ⟨hX, allIn_of_last hv hi hX (by simpa [memL, width] using h)⟩)
  · have hk := kinded_of_enP (hi _ h)
    have hX : Kinded (chunked p ch) (.xfer c) := by
      have := kinded_up hv (x := .xfer _) hk; simpa [up, hmc] using this
    exact Or.inr ((ha _).mpr ⟨hX, allIn_of_last hv hi hX (by simpa [memL, width] using h)⟩)

/-- An event's label in the element program has fired: so it has in the chunked one. -/
theorem ev_fc {Fc F : List Label} (ha : Agree p ch Fc F) {y : Label} (hy : y ∈ F)
    (hev : (∃ v, y = .start v) ∨ (∃ v, y = .finish v)) : y ∈ Fc := by
  rcases hev with ⟨v, rfl⟩ | ⟨v, rfl⟩
  · exact (ha _).mpr ⟨trivial, fun x hx => by rw [mem_start hx]; exact hy⟩
  · exact (ha _).mpr ⟨trivial, fun x hx => by rw [mem_finish hx]; exact hy⟩

/-- The previous chunk's last member, for the first member of chunk `c`. -/
theorem prev_chunk (hv : Valid p ch) {c j : Nat} (hc : c < ch.members.size)
    (hj : (p.el (ch.mem c 0)).prev = some j) :
    ch.chunk j < ch.members.size ∧ ch.mem (ch.chunk j) (ch.len (ch.chunk j) - 1) = j ∧ ch.chunk j ≠ c :=
  let h := prev_last hv hc hj; ⟨h.2.1, h.2.2, hv.notSelf c hc j hj⟩

theorem el_of {k : Nat} {e : Elem} (hk : k < p.elems.size) (h : p.elems[k]? = some e) : e = p.el k := by
  rw [el_some hk] at h; exact (Option.some.inj h).symm

theorem en_read_el {F : List Label} {k : Nat} (h : En p F (.read k)) (hk : k < p.elems.size) :
    (∃ s, (p.el k).src = some s ∧ Label.start s ∈ F) ∧ ∀ j, (p.el k).prev = some j → Label.read j ∈ F := by
  obtain ⟨e, he, hs, hp⟩ := h
  rw [el_of hk he] at hs hp; exact ⟨hs, hp⟩

theorem en_push_el {F : List Label} {k : Nat} (h : En p F (.push k)) (hk : k < p.elems.size) :
    Label.read k ∈ F ∧ ∀ j, (p.el k).prev = some j → Sent F j := by
  obtain ⟨e, he, _, hr, hp⟩ := h
  rw [el_of hk he] at hp; exact ⟨hr, hp⟩

theorem en_pull_el {F : List Label} {k i : Nat} (h : En p F (.pull k i)) (hk : k < p.elems.size) :
    (∃ d, (p.el k).dsts[i]? = some (some d) ∧ Label.start d ∈ F) ∧ Label.push k ∈ F ∧
      ∀ j, (p.el k).prev = some j → Got F j i := by
  obtain ⟨e, he, _, hd, hpu, hp⟩ := h
  rw [el_of hk he] at hd hp; exact ⟨hd, hpu, hp⟩

theorem en_xfer_el {F : List Label} {k : Nat} (h : En p F (.xfer k)) (hk : k < p.elems.size) :
    Label.read k ∈ F ∧ AllStarted F (p.el k) ∧
      ∀ j, (p.el k).prev = some j → ∀ i, i < (p.el k).dsts.length → Got F j i := by
  obtain ⟨e, he, _, hr, has, hp⟩ := h
  rw [el_of hk he] at has hp; exact ⟨hr, has, hp⟩

theorem chunked_some {c : Nat} (hc : c < ch.members.size) :
    (chunked p ch).elems[c]? = some (ecOf p ch c) := by rw [chunked_get]; simp [hc]

theorem prev_map {c c' : Nat} (h : (ecOf p ch c).prev = some c') :
    ∃ j, (p.el (ch.mem c 0)).prev = some j ∧ c' = ch.chunk j := by
  simp only [ecOf, Option.map_eq_some_iff] at h
  obtain ⟨j, hj, rfl⟩ := h
  exact ⟨j, hj, rfl⟩

theorem sent_drop {F : List Label} {x : Label} {j : Nat} (h : Sent (x :: F) j)
    (hx : x ≠ .push j) (hx' : x ≠ .xfer j) : Sent F j := by
  rcases h with h | h
  · exact Or.inl ((List.mem_cons.mp h).resolve_left (Ne.symm hx))
  · exact Or.inr ((List.mem_cons.mp h).resolve_left (Ne.symm hx'))

theorem got_drop {F : List Label} {x : Label} {j i : Nat} (h : Got (x :: F) j i)
    (hx : x ≠ .pull j i) (hx' : x ≠ .xfer j) : Got F j i := by
  rcases h with h | h
  · exact Or.inl ((List.mem_cons.mp h).resolve_left (Ne.symm hx))
  · exact Or.inr ((List.mem_cons.mp h).resolve_left (Ne.symm hx'))

/-- **A chunked label may fire once its last member has**: what its members waited for, outside
its chunk, the chunked program has fired. -/
theorem en_chunked (hv : Valid p ch) {Fc F : List Label} {x : Label}
    (hi : Inv p (x :: F)) (hiF : Inv p F) (ha : Agree p ch Fc F) (hx : En p F x)
    (hall : AllIn p ch (up ch x) (x :: F)) : En (chunked p ch) Fc (up ch x) := by
  have other (y : Label) (hy : y ∈ x :: F) (hne : y ≠ x) : y ∈ F :=
    (List.mem_cons.mp hy).resolve_left hne
  have hkx := kinded_of_enP hx
  cases x with
  | start v =>
    obtain ⟨hv', hpre⟩ := hx
    exact ⟨hv', fun u hu => ev_fc ha (hpre u hu) (Or.inr ⟨u, rfl⟩)⟩
  | finish v =>
    obtain ⟨hv', hst, hel⟩ := hx
    refine ⟨hv', ev_fc ha hst (Or.inl ⟨v, rfl⟩), fun c ec hec => ?_⟩
    have hc : c < ch.members.size := by
      rw [chunked_get] at hec; split at hec
      · assumption
      · simp at hec
    rw [chunked_some hc] at hec; cases hec
    have hn := hv.nonempty c hc
    obtain ⟨hm, hmc, _⟩ := memL_elem hv hc (show ch.len c - 1 < ch.len c by omega)
    have hk := hel _ _ (el_some hm)
    obtain ⟨hsrc, hdst, _⟩ := same_k hv hm
    rw [hmc] at hsrc hdst
    exact ⟨fun hs => sent_fc hv hiF ha hc (hk.1 (by rw [hsrc]; simpa [ecOf] using hs)),
      fun i hi' => got_fc hv hiF ha hc (hk.2 i (by rw [hdst]; simpa [ecOf] using hi'))⟩
  | read k =>
    have hk : k < p.elems.size := hkx
    have hc := (hv.cover k hk).1
    have h0 := memL_elem hv hc (hv.nonempty (ch.chunk k) hc)
    have hr0 := hall (.read (ch.mem (ch.chunk k) 0)) ⟨h0.1, by simp [up, h0.2.1]⟩
    obtain ⟨⟨s, hs, hst⟩, hpre⟩ := en_read_el (hi _ hr0) h0.1
    refine ⟨ecOf p ch (ch.chunk k), chunked_some hc,
      ⟨s, by simpa [ecOf] using hs, ev_fc ha (other _ hst (by simp)) (Or.inl ⟨s, rfl⟩)⟩, fun c' hc' => ?_⟩
    obtain ⟨j, hj, rfl⟩ := prev_map hc'
    obtain ⟨hcj, hlast, hne⟩ := prev_chunk hv hc hj
    have hrj := other _ (hpre j hj) (by intro h; cases h; exact hne rfl)
    have hX : Kinded (chunked p ch) (.read (ch.chunk j)) := by simpa [Kinded, chunked_size] using hcj
    exact (ha _).mpr ⟨hX, allIn_of_last hv hiF hX (by simpa [memL, width, hlast] using hrj)⟩
  | push k =>
    have hk : k < p.elems.size := hkx.1
    have hc := (hv.cover k hk).1
    have hbc : (p.el (ch.mem (ch.chunk k) 0)).buffered = true := by rw [chunk_buffered hv hk]; exact hkx.2
    have h0 := memL_elem hv hc (hv.nonempty (ch.chunk k) hc)
    have hp0 := hall (.push _) ⟨⟨h0.1, by rw [buffered_k hv h0.1, h0.2.1]; exact hbc⟩, by simp [up, h0.2.1]⟩
    obtain ⟨_, hpre⟩ := en_push_el (hi _ hp0) h0.1
    refine ⟨ecOf p ch (ch.chunk k), chunked_some hc, by simpa [ecOf] using hbc, ?_, fun c' hc' => ?_⟩
    · -- Every member's read has fired: before its entry.
      have hX : Kinded (chunked p ch) (.read (ch.chunk k)) := by simpa [Kinded, chunked_size] using hc
      refine (ha _).mpr ⟨hX, fun y hy => ?_⟩
      obtain ⟨m, rfl, hmc, hm⟩ := mem_read (k := 0) hy
      have hpm := hall (.push m) ⟨⟨hm, by rw [buffered_k hv hm, hmc]; exact hbc⟩, by simp [up, hmc]⟩
      exact other _ (en_push_el (hi _ hpm) hm).1 (by simp)
    · obtain ⟨j, hj, rfl⟩ := prev_map hc'
      obtain ⟨hcj, hlast, hne⟩ := prev_chunk hv hc hj
      have hjk : j ≠ k := by intro h; subst h; exact hne rfl
      have hsj := sent_drop (hpre j hj) (by simp; exact Ne.symm hjk) (by simp)
      exact sent_fc hv hiF ha hcj (by rw [hlast]; exact hsj)
  | pull k i =>
    have hk : k < p.elems.size := hkx.1
    have hc := (hv.cover k hk).1
    have hbc : (p.el (ch.mem (ch.chunk k) 0)).buffered = true := by rw [chunk_buffered hv hk]; exact hkx.2
    have h0 := memL_elem hv hc (hv.nonempty (ch.chunk k) hc)
    have hp0 := hall (.pull _ i) ⟨⟨h0.1, by rw [buffered_k hv h0.1, h0.2.1]; exact hbc⟩, by simp [up, h0.2.1]⟩
    obtain ⟨⟨d, hd, hsd⟩, _, hpre⟩ := en_pull_el (hi _ hp0) h0.1
    refine ⟨ecOf p ch (ch.chunk k), chunked_some hc, by simpa [ecOf] using hbc,
      ⟨d, by simpa [ecOf] using hd, ev_fc ha (other _ hsd (by simp)) (Or.inl ⟨d, rfl⟩)⟩, ?_,
      fun c' hc' => ?_⟩
    · have hX : Kinded (chunked p ch) (.push (ch.chunk k)) :=
        ⟨by simpa [chunked_size] using hc, by rw [chunked_el hc]; simpa [ecOf] using hbc⟩
      refine (ha _).mpr ⟨hX, fun y hy => ?_⟩
      obtain ⟨m, rfl, hmc, hm, hbm⟩ := mem_push hy
      have hpm := hall (.pull m i) ⟨⟨hm, hbm⟩, by simp [up, hmc]⟩
      exact other _ (en_pull_el (hi _ hpm) hm).2.1 (by simp)
    · obtain ⟨j, hj, rfl⟩ := prev_map hc'
      obtain ⟨hcj, hlast, hne⟩ := prev_chunk hv hc hj
      have hjk : j ≠ k := by intro h; subst h; exact hne rfl
      have hgj := got_drop (hpre j hj) (by simp; exact Ne.symm hjk) (by simp)
      exact got_fc hv hiF ha hcj (by rw [hlast]; exact hgj)
  | xfer k =>
    have hk : k < p.elems.size := hkx.1
    have hc := (hv.cover k hk).1
    have hbc : (p.el (ch.mem (ch.chunk k) 0)).buffered = false := by rw [chunk_buffered hv hk]; exact hkx.2
    have h0 := memL_elem hv hc (hv.nonempty (ch.chunk k) hc)
    have hx0 := hall (.xfer _) ⟨⟨h0.1, by rw [buffered_k hv h0.1, h0.2.1]; exact hbc⟩, by simp [up, h0.2.1]⟩
    obtain ⟨_, ⟨hne0, hst⟩, hpre⟩ := en_xfer_el (hi _ hx0) h0.1
    refine ⟨ecOf p ch (ch.chunk k), chunked_some hc, by simpa [ecOf] using hbc, ?_,
      ⟨by simpa [ecOf] using hne0, fun o ho => ?_⟩, fun c' hc' i hi' => ?_⟩
    · have hX : Kinded (chunked p ch) (.read (ch.chunk k)) := by simpa [Kinded, chunked_size] using hc
      refine (ha _).mpr ⟨hX, fun y hy => ?_⟩
      obtain ⟨m, rfl, hmc, hm⟩ := mem_read (k := 0) hy
      have hxm := hall (.xfer m) ⟨⟨hm, by rw [buffered_k hv hm, hmc]; exact hbc⟩, by simp [up, hmc]⟩
      exact other _ (en_xfer_el (hi _ hxm) hm).1 (by simp)
    · obtain ⟨d, rfl, hsd⟩ := hst o (by simpa [ecOf] using ho)
      exact ⟨d, rfl, ev_fc ha (other _ hsd (by simp)) (Or.inl ⟨d, rfl⟩)⟩
    · obtain ⟨j, hj, rfl⟩ := prev_map hc'
      obtain ⟨hcj, hlast, hne⟩ := prev_chunk hv hc hj
      have hjk : j ≠ k := by intro h; subst h; exact hne rfl
      have hgj := got_drop (hpre j hj i (by simpa [ecOf] using hi')) (by simp) (by simp; exact Ne.symm hjk)
      exact got_fc hv hiF ha hcj (by rw [hlast]; exact hgj)

/-- **A complete execution of the element program gives one of the chunked program**: a chunked
label fires when its last member has. -/
theorem chunked_of_completes (hv : Valid p ch) {t G : List Label} (hr : Run p [] t G)
    (hd : Done p G) : ∃ tc Gc, Run (chunked p ch) [] tc Gc ∧ Done (chunked p ch) Gc := by
  have go : ∀ {F t G}, Run p F t G → Inv p F → ∀ tc Fc, Run (chunked p ch) [] tc Fc →
      Agree p ch Fc F → ∃ tc' Gc, Run (chunked p ch) [] tc' Gc ∧ Agree p ch Gc G := by
    intro F t G r
    induction r with
    | nil => exact fun _ tc Fc hrc ha => ⟨tc, Fc, hrc, ha⟩
    | @cons F x t G hen hnot rest ih =>
      intro hiF tc Fc hrc ha
      have hi : Inv p (x :: F) := Run.inv (.cons hen hnot (.nil _)) hiF
      have hkx := kinded_of_enP hen
      -- Other labels' members are not `x`.
      have notx (Y : Label) (hY : Y ≠ up ch x) (hall : AllIn p ch Y (x :: F)) : AllIn p ch Y F := by
        intro y hy
        refine (List.mem_cons.mp (hall y hy)).resolve_left ?_
        rintro rfl; exact hY hy.2.symm
      by_cases hall : AllIn p ch (up ch x) (x :: F)
      · have he := en_chunked hv hi hiF ha hen hall
        have hX : up ch x ∉ Fc := fun h => hnot (((ha _).mp h).2 x ⟨hkx, rfl⟩)
        refine ih hi (tc ++ [up ch x]) (up ch x :: Fc) (hrc.append he hX) fun Y => ⟨fun hY => ?_, fun ⟨hk, hY⟩ => ?_⟩
        · rcases List.mem_cons.mp hY with rfl | hY
          · exact ⟨kinded_up hv hkx, hall⟩
          · obtain ⟨hk, hall'⟩ := (ha Y).mp hY
            exact ⟨hk, fun y hy => List.mem_cons_of_mem _ (hall' y hy)⟩
        · by_cases hYX : Y = up ch x
          · exact hYX ▸ List.mem_cons_self ..
          · exact List.mem_cons_of_mem _ ((ha Y).mpr ⟨hk, notx Y hYX hY⟩)
      · refine ih hi tc Fc hrc fun Y => ⟨fun hY => ?_, fun ⟨hk, hY⟩ => ?_⟩
        · obtain ⟨hk, hall'⟩ := (ha Y).mp hY
          exact ⟨hk, fun y hy => List.mem_cons_of_mem _ (hall' y hy)⟩
        · have hYX : Y ≠ up ch x := fun h => hall (h ▸ hY)
          exact (ha Y).mpr ⟨hk, notx Y hYX hY⟩
  have agree0 : Agree p ch [] [] := fun Y => ⟨fun h => absurd h List.not_mem_nil, fun ⟨hk, hY⟩ =>
    absurd (hY _ (memL_mem hv hk (width_pos hv hk))) List.not_mem_nil⟩
  obtain ⟨tc, Gc, hrc, ha⟩ := go hr (fun _ h => absurd h List.not_mem_nil) [] [] (.nil _) agree0
  refine ⟨tc, Gc, hrc, fun v hv' => (ha _).mpr ⟨trivial, fun y hy => ?_⟩⟩
  rw [mem_finish hy]
  exact hd v (by simpa [chunked] using hv')

/-- **Completion is the same in both programs.** -/
theorem completes_iff (hv : Valid p ch) :
    (∃ t G, Run (chunked p ch) [] t G ∧ Done (chunked p ch) G) ↔ ∃ t G, Run p [] t G ∧ Done p G :=
  ⟨fun ⟨_, _, hr, hd⟩ => completes_of_chunked hv hr hd, fun ⟨_, _, hr, hd⟩ => chunked_of_completes hv hr hd⟩

/-! ### Checking a chunking -/

def coverB (p : Prog) (ch : Chunking) (k : Nat) : Bool :=
  decide (ch.chunk k < ch.members.size) && decide (ch.idx k < ch.len (ch.chunk k)) &&
    ch.mem (ch.chunk k) (ch.idx k) == k

def memberB (p : Prog) (ch : Chunking) (c a : Nat) : Bool :=
  ch.chunk (ch.mem c a) == c && ch.idx (ch.mem c a) == a && decide (ch.mem c a < p.elems.size) &&
  (p.el (ch.mem c a)).src == (p.el (ch.mem c 0)).src &&
  (p.el (ch.mem c a)).dsts == (p.el (ch.mem c 0)).dsts &&
  (p.el (ch.mem c a)).buffered == (p.el (ch.mem c 0)).buffered &&
  (!(decide (a + 1 < ch.len c)) || (p.el (ch.mem c (a + 1))).prev == some (ch.mem c a))

def firstB (p : Prog) (ch : Chunking) (c : Nat) : Bool :=
  match (p.el (ch.mem c 0)).prev with
  | none => true
  | some j => decide (j < p.elems.size) && ch.idx j + 1 == ch.len (ch.chunk j) && ch.chunk j != c

def xferB (p : Prog) (ch : Chunking) (c : Nat) : Bool :=
  decide (ch.len c ≤ 1) || (p.el (ch.mem c 0)).buffered || !(p.el (ch.mem c 0)).dsts.isEmpty

/-- Decides `Valid`. -/
def validB (p : Prog) (ch : Chunking) : Bool :=
  (List.range p.elems.size).all (coverB p ch) &&
  (List.range ch.members.size).all fun c =>
    decide (0 < ch.len c) && (List.range (ch.len c)).all (memberB p ch c) && firstB p ch c && xferB p ch c

theorem valid_of_validB (h : validB p ch = true) : Valid p ch := by
  simp only [validB, Bool.and_eq_true, List.all_eq_true, List.mem_range] at h
  obtain ⟨hk, hc⟩ := h
  have cov (k : Nat) (hk' : k < p.elems.size) := by
    have := hk k hk'; simp only [coverB, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at this
    exact this
  have mb (c : Nat) (hc' : c < ch.members.size) (a : Nat) (ha : a < ch.len c) := by
    have := (hc c hc').1.1.2 a ha
    simp only [memberB, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, Bool.or_eq_true,
      Bool.not_eq_true', decide_eq_false_iff_not] at this
    exact this
  refine ⟨fun k hk' => ⟨(cov k hk').1.1, (cov k hk').1.2, (cov k hk').2⟩,
    fun c hc' a ha => ?_, fun c hc' => by simpa using (hc c hc').1.1.1, fun c hc' a ha => ?_,
    fun c hc' a ha => ?_, fun c hc' j hj => ?_, fun c hc' j hj => ?_, fun c hc' hlen hb => ?_⟩
  · obtain ⟨⟨⟨⟨⟨⟨h1, h2⟩, h3⟩, _⟩, _⟩, _⟩, _⟩ := mb c hc' a ha
    exact ⟨h1, h2, h3⟩
  · rcases (mb c hc' a (by omega)).2 with h | h
    · exact absurd ha h
    · exact h
  · obtain ⟨⟨⟨⟨⟨⟨_, _⟩, _⟩, h4⟩, h5⟩, h6⟩, _⟩ := mb c hc' a ha
    exact ⟨h4, h5, h6⟩
  · have := (hc c hc').1.2
    simp only [firstB, hj, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, bne_iff_ne, ne_eq] at this
    exact ⟨this.1.1, this.1.2⟩
  · have := (hc c hc').1.2
    simp only [firstB, hj, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq, bne_iff_ne, ne_eq] at this
    exact this.2
  · have := (hc c hc').2
    simp only [xferB, Bool.or_eq_true, decide_eq_true_eq, hb, Bool.not_eq_true',
      List.isEmpty_eq_false_iff] at this
    rcases this with (h | h) | h
    · omega
    · cases h
    · exact h

/-! ### The chunked footprint, the chunk condition, and the verdicts -/

/-- A chunked label's footprint: its members'. -/
def chunkFp (ch : Chunking) (fp : LFp) : LFp := fun X =>
  (List.range (width ch X)).flatMap fun a => fp (memL ch X a)

theorem chunkFp_cov (hv : Valid p ch) (fp : LFp) {x : Label} (hx : Kinded p x) :
    ∀ a ∈ fp x, a ∈ chunkFp ch fp (up ch x) := by
  intro a ha
  have hm : MemOf p ch x (up ch x) := ⟨hx, rfl⟩
  simp only [chunkFp, List.mem_flatMap, List.mem_range]
  exact ⟨eidx ch x, eidx_lt hv hm, by rw [← member_eq hv hm]; exact ha⟩

/-- The element a member's label is of, as a stream position. -/
def elemPos (x : Label) : Int := match elemOf x with
  | some k => Int.ofNat k
  | none => -1

/-- The labels a chunked label `T` follows along its chunk's own steps. -/
def sources : Label → List Label
  | .push c => [.read c]
  | .pull c i => [.read c, .push c]
  | .xfer c => [.read c]
  | _ => []

/-- `l` without repeats: linear in `l` times the number of distinct elements. -/
def dedupBK (l : List (Nat × Bool)) : List (Nat × Bool) :=
  l.foldl (fun acc x => if acc.contains x then acc else x :: acc) []

theorem mem_dedupBK {l : List (Nat × Bool)} {x : Nat × Bool} (h : x ∈ l) : x ∈ dedupBK l := by
  suffices H : ∀ (l : List (Nat × Bool)) (acc : List (Nat × Bool)),
      (x ∈ acc ∨ x ∈ l) → x ∈ l.foldl (fun acc x => if acc.contains x then acc else x :: acc) acc from
    H l [] (Or.inr h)
  intro l
  induction l with
  | nil => intro acc h; simpa using h
  | cons y ys ih =>
    intro acc h
    apply ih
    simp only [List.mem_cons] at h
    show x ∈ (if acc.contains y = true then acc else y :: acc) ∨ x ∈ ys
    split
    · rename_i hc
      rcases h with h | rfl | h
      · exact Or.inl h
      · exact Or.inl (by simpa using hc)
      · exact Or.inr h
    · rcases h with h | rfl | h
      · exact Or.inl (List.mem_cons_of_mem _ h)
      · exact Or.inl (List.mem_cons_self ..)
      · exact Or.inr h

/-- Accesses of the members of `X` to buffers other than `slot`, as (buffer, writes). -/
def bufKinds (ch : Chunking) (fp : LFp) (slot : Nat) (X : Label) : List (Nat × Bool) :=
  dedupBK ((List.range (width ch X)).flatMap fun a => (fp (memL ch X a)).filterMap fun acc =>
    if acc.buf = slot then none else some (acc.buf, acc.kind == .write))

/-- Members of `X` touch the stream slot `slot` only at their own element. -/
def slotOwnB (ch : Chunking) (fp : LFp) (slot : Nat) (X : Label) : Bool :=
  (List.range (width ch X)).all fun a =>
    (fp (memL ch X a)).all fun acc => acc.buf != slot || acc.elems.all (· == elemPos (memL ch X a))

/-- `X` (a source of `T`) and `T` do not conflict but at a member's own slot. -/
def pairCondB (ch : Chunking) (fp : LFp) (slot : Nat) (X T : Label) : Bool :=
  decide (width ch T ≤ 1) || slotOwnB ch fp slot X && slotOwnB ch fp slot T &&
  let bt := bufKinds ch fp slot T
  (bufKinds ch fp slot X).all fun (b, w) => bt.all fun (b', w') => b != b' || (!w && !w')

/-- Decides the chunk condition for the labels of `tc`. -/
def condB (ch : Chunking) (fp : LFp) (slot : Nat) (tc : List Label) : Bool :=
  tc.all fun T => (sources T).all fun X => pairCondB ch fp slot X T

theorem elem_left {x : Label} {Y : Label} (hi : Internal (up ch x) Y) : elemOf x ≠ none := by
  cases x <;> cases Y <;> simp [Internal, up, elemOf] at hi ⊢

theorem elem_right {X : Label} {y : Label} (hi : Internal X (up ch y)) : elemOf y ≠ none := by
  cases y <;> cases X <;> simp [Internal, up, elemOf] at hi ⊢

theorem internal_sources {X T : Label} (hi : Internal X T) (hne : X ≠ T) : X ∈ sources T := by
  cases X <;> cases T <;> simp_all [Internal, sources]

theorem mem_bufKinds {fp : LFp} {slot : Nat} {X : Label} {a : Nat} (ha : a < width ch X)
    {acc : Access} (hacc : acc ∈ fp (memL ch X a)) (hs : acc.buf ≠ slot) :
    (acc.buf, acc.kind == .write) ∈ bufKinds ch fp slot X := by
  apply mem_dedupBK
  simp only [List.mem_flatMap, List.mem_range, List.mem_filterMap]
  exact ⟨a, ha, acc, hacc, by simp [hs]⟩

theorem slot_elems {fp : LFp} {slot : Nat} {X : Label} (h : slotOwnB ch fp slot X = true)
    {a : Nat} (ha : a < width ch X) {acc : Access} (hacc : acc ∈ fp (memL ch X a))
    (hs : acc.buf = slot) : ∀ e ∈ acc.elems, e = elemPos (memL ch X a) := by
  simp only [slotOwnB, List.all_eq_true, List.mem_range, Bool.or_eq_true, bne_iff_ne, ne_eq,
    beq_iff_eq] at h
  rcases h a ha acc hacc with h | h
  · exact absurd hs h
  · exact h

theorem elemPos_inj {x y : Label} (hx : elemOf x ≠ none) (hy : elemOf y ≠ none)
    (h : elemPos x = elemPos y) : elemOf x = elemOf y := by
  cases hex : elemOf x with
  | none => exact absurd hex hx
  | some k =>
    cases hey : elemOf y with
    | none => exact absurd hey hy
    | some k' => simp only [elemPos, hex, hey] at h; exact congrArg some (Int.ofNat.inj h)

/-- **`condB` decides the chunk condition** for the labels whose chunked labels are in `tc`. -/
theorem condOk_of_condB (hv : Valid p ch) {fp : LFp} {slot : Nat} {tc : List Label}
    (h : condB ch fp slot tc = true) : CondOk p ch fp fun x => Kinded p x ∧ up ch x ∈ tc := by
  intro x y _ hSy hkx hky hi hne hlt hconf
  have hsrc := internal_sources hi hne
  have hp : pairCondB ch fp slot (up ch x) (up ch y) = true := by
    simp only [condB, List.all_eq_true] at h
    exact h _ hSy.2 _ hsrc
  have mx : MemOf p ch x (up ch x) := ⟨hkx, rfl⟩
  have my : MemOf p ch y (up ch y) := ⟨hky, rfl⟩
  have hax := eidx_lt hv mx
  have hay := eidx_lt hv my
  simp only [pairCondB, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true, List.all_eq_true,
    bne_iff_ne, ne_eq, Bool.not_eq_true', Prod.forall] at hp
  rcases hp with hw1 | ⟨⟨hsx, hsy⟩, hbk⟩
  · -- One member: nothing comes before it in its chunk. `x`'s chunk is `y`'s.
    have hwx : width ch (up ch x) = width ch (up ch y) := by
      cases x <;> cases y <;> simp_all [Internal, up, width]
    omega
  have ex := member_eq hv mx
  have ey := member_eq hv my
  obtain ⟨acc, hacc, acc', hacc', hbuf, hw, e, he, he'⟩ := hconf
  rw [ex] at hacc
  rw [ey] at hacc'
  by_cases hs : acc.buf = slot
  · -- At the stream slot: each member at its own element.
    have h1 := slot_elems hsx hax hacc hs e he
    have h2 := slot_elems hsy hay hacc' (hbuf ▸ hs) e he'
    rw [← ex] at h1
    rw [← ey] at h2
    -- Both are element labels of one chunk (`Internal`).
    have hxe := elem_left hi
    have hye := elem_right hi
    have heq := elemPos_inj hxe hye (h1.symm.trans h2)
    have : eidx ch x = eidx ch y := by simp [eidx, heq]
    omega
  · have k1 := mem_bufKinds hax hacc hs
    have k2 := mem_bufKinds hay hacc' (hbuf ▸ hs)
    rcases hbk _ _ k1 _ _ k2 with h | ⟨h1, h2⟩
    · exact h hbuf
    · rcases hw with hw | hw
      · simp [hw] at h1
      · simp [hw] at h2

/-- **The verdicts of the chunked program are the element program's**: if it completes and is
race-free, and the chunking and the chunk condition check, the element program completes (and
then from anywhere, `completes_from_anywhere`) and is race-free on the labels of the chunked
labels of `tc`. -/
theorem chunked_sound {fp : LFp} {slot : Nat} {idx : Array (List Nat)} {tc : List Label}
    (hv : validB p ch = true) (hcond : condB ch fp slot tc = true)
    (hc : checkH (chunked p ch) idx tc = some true)
    (hr : racesOkE (chunked p ch) idx (chunkFp ch fp) tc = true) :
    (∃ t G, Run p [] t G ∧ Done p G) ∧ RaceFree p fp fun x => Kinded p x ∧ up ch x ∈ tc := by
  have hv' := valid_of_validB hv
  obtain ⟨G, r, d⟩ := checkH_true hc
  refine ⟨completes_of_chunked hv' r d, ?_⟩
  exact raceFree_of_chunked hv' (condOk_of_condB hv' hcond) (fun x hx => chunkFp_cov hv' fp hx)
    (fun x h => ⟨h.1, h.2⟩) (raceFree_of_racesOkE hr)

/-- **A deadlock of the chunked program is one of the element program.** -/
theorem chunked_deadlock {idx : Array (List Nat)} {tc : List Label} (hv : validB p ch = true)
    (hc : checkH (chunked p ch) idx tc = some false) : ¬ ∃ t G, Run p [] t G ∧ Done p G :=
  fun h => checkH_false hc ((completes_iff (valid_of_validB hv)).mpr h)

/-- **Outcomes, through the chunked program**: the expansion of its complete execution is a
complete execution of the element program, and every complete execution of the element program
ends as it does. -/
theorem outcome_uniqueC {V : Type} {fp : LFp} {eff : Label → Mem V → Mem V} {slot : Nat}
    {idx : Array (List Nat)} {tc : List Label} (hw : wfB p = true) (hfr : LFramed fp eff)
    (hv : validB p ch = true) (hcond : condB ch fp slot tc = true)
    (hc : checkH (chunked p ch) idx tc = some true)
    (hr : racesOkE (chunked p ch) idx (chunkFp ch fp) tc = true)
    {t' G' : List Label} (h : Run p [] t' G') (d : Done p G') (m : Mem V) :
    runL eff t' m = runL eff (tc.flatMap (expandL ch)) m := by
  have hv' := valid_of_validB hv
  obtain ⟨Gc, rc, dc⟩ := checkH_true hc
  obtain ⟨G, r, dG⟩ := expand_run hv' rc dc
  have hrf := (chunked_sound hv hcond hc hr).2
  -- The expansion's labels are members of labels of `tc`.
  have hS : RaceFree p fp (· ∈ tc.flatMap (expandL ch)) := by
    intro x y hx hy hne hcf
    have mem (z : Label) (hz : z ∈ tc.flatMap (expandL ch)) : Kinded p z ∧ up ch z ∈ tc := by
      simp only [List.mem_flatMap, expandL, List.mem_map, List.mem_range] at hz
      obtain ⟨X, hX, a, ha, rfl⟩ := hz
      have hk := kinded_of_en (rc.inv Inv.nil X ((rc.mem X).mpr (Or.inl hX)))
      have hm := memL_mem hv' hk ha
      exact ⟨hm.1, by rw [hm.2]; exact hX⟩
    exact hrf x y (mem x hx) (mem y hy) hne hcf
  exact (deterministic (wf_of_wfB hw) hfr r dG h d hS m).symm

end Chan

end

end Veir.Air
