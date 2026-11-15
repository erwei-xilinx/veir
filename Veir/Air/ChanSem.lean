module

public import Veir.Air.DepGraph

namespace Veir.Air

@[expose] public section

/-! # Layer 4: a small-step semantics of channels, and what it implies

This file is the semantics of `SEMANTICS.md` D28–D36 and D51, stated without reference to any
checker, and the theorems that make a checker for it trustworthy.

## The model

A program has events `0, …, n-1` with a dependency graph, as in `Veir.Air.Events`, and stream
*elements* `0, …, m-1`. Each element belongs to one subchannel's stream (D28, D34):
- `src`: the put event that sends it, if any put does;
- `dst`: the get event that receives it, if any get does;
- `prev`: the element before it in the same subchannel, if any;
- `buffered`: whether its transfer is buffered. D51: an element is buffered iff its put or its
  get is synchronous (a missing end counts as asynchronous); otherwise put and get meet (D30).

Which put and get an element belongs to follows from D33 and D34 (the i-th element put is the
i-th element got); computing it from IR is `Veir.Air.Channels`' job, not this file's.

An execution fires labels, each at most once:
- `start v`, `finish v`: an event starts once everything it waits for has finished, and
  finishes once all its elements have left (a put) or arrived (a get);
- `read k`: the put reads element `k`'s source, in stream order, at any time after it started
  (D36(a): reads may run ahead of the stream);
- `push k` / `pull k`: a buffered element enters, then leaves, the subchannel's buffer;
- `xfer k`: an unbuffered element passes from a running put to a running get in one step.

The stream is FIFO: an element enters after the one before it entered, and leaves after it left.

## What is proven

- `Run.replay` / `completes_from_anywhere`: **deadlock does not depend on the schedule.** If one
  execution completes, then from every state any execution reaches, some execution still
  completes. So no execution of such a program can get stuck.
- `check_true` / `check_false`: a checker that fires enabled labels greedily decides it, both
  ways.

The proofs rest on one property of the semantics: a label enabled in some state stays enabled
after any other label fires (`En.mono`), because every condition asks that some labels *have*
fired, never that some have not.
-/

namespace Chan

structure Elem where
  src : Option Nat
  dst : Option Nat
  prev : Option Nat
  buffered : Bool
deriving Repr, Inhabited, DecidableEq

structure Prog where
  graph : DepGraph
  elems : Array Elem
deriving Inhabited

inductive Label where
  | start (v : Nat)
  | finish (v : Nat)
  | read (k : Nat)
  | push (k : Nat)
  | pull (k : Nat)
  | xfer (k : Nat)
deriving DecidableEq, Repr, Inhabited

/-- Element `k` has entered the stream. -/
def Sent (F : List Label) (k : Nat) : Prop := Label.push k ∈ F ∨ Label.xfer k ∈ F

/-- Element `k` has been received. -/
def Got (F : List Label) (k : Nat) : Prop := Label.pull k ∈ F ∨ Label.xfer k ∈ F

/-- Label `l` may fire once the labels `F` have. -/
def En (p : Prog) (F : List Label) : Label → Prop
  | .start v => v < p.graph.size ∧ ∀ u ∈ p.graph.predsOf v, Label.finish u ∈ F
  | .finish v => v < p.graph.size ∧ Label.start v ∈ F ∧
      ∀ k e, p.elems[k]? = some e → (e.src = some v → Sent F k) ∧ (e.dst = some v → Got F k)
  | .read k => ∃ e, p.elems[k]? = some e ∧ (∃ s, e.src = some s ∧ Label.start s ∈ F) ∧
      ∀ j, e.prev = some j → Label.read j ∈ F
  | .push k => ∃ e, p.elems[k]? = some e ∧ e.buffered = true ∧ Label.read k ∈ F ∧
      ∀ j, e.prev = some j → Sent F j
  | .pull k => ∃ e, p.elems[k]? = some e ∧ e.buffered = true ∧
      (∃ d, e.dst = some d ∧ Label.start d ∈ F) ∧ Label.push k ∈ F ∧
      ∀ j, e.prev = some j → Got F j
  | .xfer k => ∃ e, p.elems[k]? = some e ∧ e.buffered = false ∧ Label.read k ∈ F ∧
      (∃ d, e.dst = some d ∧ Label.start d ∈ F) ∧ ∀ j, e.prev = some j → Got F j

/-- `Run p F t G`: from the fired labels `F`, the labels `t` fire in order, each once, and `G`
have fired at the end. -/
inductive Run (p : Prog) : List Label → List Label → List Label → Prop
  | nil (F : List Label) : Run p F [] F
  | cons {F : List Label} {l : Label} {t G : List Label} :
      En p F l → l ∉ F → Run p (l :: F) t G → Run p F (l :: t) G

/-- Every event has finished. -/
def Done (p : Prog) (F : List Label) : Prop := ∀ v, v < p.graph.size → Label.finish v ∈ F

/-- No label can fire. -/
def Stuck (p : Prog) (F : List Label) : Prop := ∀ l, l ∉ F → ¬ En p F l

variable {p : Prog}

def Sub (F G : List Label) : Prop := ∀ x, x ∈ F → x ∈ G

theorem Sent.mono {F G : List Label} {k : Nat} (h : Sent F k) (s : Sub F G) : Sent G k := by
  rcases h with h | h
  · exact Or.inl (s _ h)
  · exact Or.inr (s _ h)

theorem Got.mono {F G : List Label} {k : Nat} (h : Got F k) (s : Sub F G) : Got G k := by
  rcases h with h | h
  · exact Or.inl (s _ h)
  · exact Or.inr (s _ h)

/-- **Enabled labels stay enabled** as more labels fire. -/
theorem En.mono {F G : List Label} {l : Label} (h : En p F l) (s : Sub F G) : En p G l := by
  cases l with
  | start v => exact ⟨h.1, fun u hu => s _ (h.2 u hu)⟩
  | finish v =>
    obtain ⟨hlt, hst, he⟩ := h
    exact ⟨hlt, s _ hst, fun k e hk =>
      ⟨fun hs => ((he k e hk).1 hs).mono s, fun hd => ((he k e hk).2 hd).mono s⟩⟩
  | read k =>
    obtain ⟨e, hk, ⟨x, hx, hxs⟩, hprev⟩ := h
    exact ⟨e, hk, ⟨x, hx, s _ hxs⟩, fun j hj => s _ (hprev j hj)⟩
  | push k =>
    obtain ⟨e, hk, hb, hr, hprev⟩ := h
    exact ⟨e, hk, hb, s _ hr, fun j hj => (hprev j hj).mono s⟩
  | pull k =>
    obtain ⟨e, hk, hb, ⟨d, hd, hds⟩, hpu, hprev⟩ := h
    exact ⟨e, hk, hb, ⟨d, hd, s _ hds⟩, s _ hpu, fun j hj => (hprev j hj).mono s⟩
  | xfer k =>
    obtain ⟨e, hk, hb, hr, ⟨d, hd, hds⟩, hprev⟩ := h
    exact ⟨e, hk, hb, s _ hr, ⟨d, hd, s _ hds⟩, fun j hj => (hprev j hj).mono s⟩

namespace Run

theorem mem {F t G : List Label} (r : Run p F t G) : ∀ x, x ∈ G ↔ x ∈ t ∨ x ∈ F := by
  induction r with
  | nil => simp
  | cons _ _ _ ih =>
    intro x
    rw [ih x]
    simp only [List.mem_cons]
    constructor
    · rintro (h | h | h) <;> simp [h]
    · rintro ((h | h) | h) <;> simp [h]

theorem not_mem {F t G : List Label} (r : Run p F t G) : ∀ x ∈ t, x ∉ F := by
  induction r with
  | nil => simp
  | cons _ hn _ ih =>
    intro x hx
    simp only [List.mem_cons] at hx
    rcases hx with rfl | hx
    · exact hn
    · exact fun h => ih x hx (List.mem_cons_of_mem _ h)

theorem sub {F t G : List Label} (r : Run p F t G) : Sub F G :=
  fun x hx => (r.mem x).mpr (Or.inr hx)

theorem append {F t G : List Label} {l : Label} (r : Run p F t G) (he : En p G l) (hn : l ∉ G) :
    Run p F (t ++ [l]) (l :: G) := by
  induction r with
  | nil => exact .cons he hn (.nil _)
  | cons h₁ h₂ _ ih => exact .cons h₁ h₂ (ih he hn)

/-- **Replaying an execution after another one.** The labels of `t` that have not fired yet
can still fire, in `t`'s order, after any execution that fired more. -/
theorem replay {F t G H : List Label} (r : Run p F t G) (s : Sub F H) :
    ∃ H', Run p H (t.filter fun l => decide (l ∉ H)) H' ∧ Sub G H' ∧ Sub H H' := by
  induction r generalizing H with
  | nil F => exact ⟨H, by simpa using Run.nil H, s, fun _ h => h⟩
  | @cons F l t G he hn rest ih =>
    by_cases hl : l ∈ H
    · obtain ⟨H', r', sg, sh⟩ := ih (H := H) (fun x hx => by
        simp only [List.mem_cons] at hx
        rcases hx with rfl | hx
        · exact hl
        · exact s x hx)
      refine ⟨H', ?_, sg, sh⟩
      simpa [List.filter_cons, hl] using r'
    · have hlt : l ∉ t := fun h => rest.not_mem l h (List.mem_cons_self ..)
      obtain ⟨H', r', sg, sh⟩ := ih (H := l :: H) (fun x hx => by
        simp only [List.mem_cons] at hx ⊢
        rcases hx with rfl | hx
        · exact Or.inl rfl
        · exact Or.inr (s x hx))
      have hfeq : (t.filter fun x => decide (x ∉ l :: H)) = t.filter fun x => decide (x ∉ H) := by
        apply List.filter_congr
        intro x hx
        have : x ≠ l := fun h => hlt (h ▸ hx)
        simp [this]
      rw [hfeq] at r'
      refine ⟨H', ?_, sg, fun x hx => sh x (List.mem_cons_of_mem _ hx)⟩
      simp only [List.filter_cons, hl, not_false_eq_true, decide_true, ite_true]
      exact .cons (he.mono s) hl r'

end Run

/-- **Deadlock does not depend on the schedule.** If some execution completes, then from any
state an execution reaches, the program can still complete. -/
theorem completes_from_anywhere {s t F G : List Label} (hc : Run p [] t G) (hd : Done p G)
    (_hs : Run p [] s F) : ∃ u H, Run p F u H ∧ Done p H := by
  obtain ⟨H, r, sg, _⟩ := hc.replay (H := F) (fun _ h => absurd h (by simp))
  exact ⟨_, H, r, fun v hv => sg _ (hd v hv)⟩

/-- So a state that some execution reaches, that has not finished and where nothing can fire,
rules out every complete execution. -/
theorem no_completion_of_stuck {s F : List Label} (hs : Run p [] s F) (hst : Stuck p F)
    (hnd : ¬ Done p F) : ¬ ∃ t G, Run p [] t G ∧ Done p G := by
  rintro ⟨t, G, hc, hd⟩
  obtain ⟨u, H, r, hH⟩ := completes_from_anywhere hc hd hs
  cases r with
  | nil => exact hnd hH
  | cons he hn _ => exact hst _ hn he

/-! ### Deciding it -/

def sentB (F : List Label) (k : Nat) : Bool := F.contains (.push k) || F.contains (.xfer k)
def gotB (F : List Label) (k : Nat) : Bool := F.contains (.pull k) || F.contains (.xfer k)

theorem sentB_iff {F : List Label} {k : Nat} : sentB F k = true ↔ Sent F k := by
  simp [sentB, Sent]

theorem gotB_iff {F : List Label} {k : Nat} : gotB F k = true ↔ Got F k := by
  simp [gotB, Got]

def prevB (e : Elem) (f : Nat → Bool) : Bool :=
  match e.prev with
  | none => true
  | some j => f j

theorem prevB_iff {e : Elem} {f : Nat → Bool} {P : Nat → Prop} (hf : ∀ j, f j = true ↔ P j) :
    prevB e f = true ↔ ∀ j, e.prev = some j → P j := by
  unfold prevB
  cases e.prev with
  | none => simp
  | some j => simp [hf j]

def enB (p : Prog) (F : List Label) : Label → Bool
  | .start v => decide (v < p.graph.size) && (p.graph.predsOf v).all fun u => F.contains (.finish u)
  | .finish v => decide (v < p.graph.size) && F.contains (.start v) &&
      (List.range p.elems.size).all fun k =>
        match p.elems[k]? with
        | none => true
        | some e => (e.src != some v || sentB F k) && (e.dst != some v || gotB F k)
  | .read k =>
    match p.elems[k]? with
    | none => false
    | some e =>
      (match e.src with | none => false | some s => F.contains (.start s)) &&
        prevB e fun j => F.contains (.read j)
  | .push k =>
    match p.elems[k]? with
    | none => false
    | some e => e.buffered && F.contains (.read k) && prevB e (sentB F)
  | .pull k =>
    match p.elems[k]? with
    | none => false
    | some e => e.buffered &&
        (match e.dst with | none => false | some d => F.contains (.start d)) &&
        F.contains (.push k) && prevB e (gotB F)
  | .xfer k =>
    match p.elems[k]? with
    | none => false
    | some e => !e.buffered && F.contains (.read k) &&
        (match e.dst with | none => false | some d => F.contains (.start d)) &&
        prevB e (gotB F)

theorem optB_iff {o : Option Nat} {F : List Label} :
    (match o with | none => false | some s => F.contains (.start s)) = true ↔
      ∃ s, o = some s ∧ Label.start s ∈ F := by
  cases o <;> simp

theorem enB_iff {F : List Label} {l : Label} : enB p F l = true ↔ En p F l := by
  cases l with
  | start v => simp [enB, En]
  | finish v =>
    simp only [enB, En, Bool.and_eq_true, decide_eq_true_eq, List.contains_iff_mem,
      List.all_eq_true, List.mem_range]
    constructor
    · rintro ⟨⟨hlt, hst⟩, h⟩
      refine ⟨hlt, hst, fun k e hk => ?_⟩
      have hks : k < p.elems.size := by
        rcases Nat.lt_or_ge k p.elems.size with h' | h'
        · exact h'
        · simp [Array.getElem?_eq_none h'] at hk
      have := h k hks
      rw [hk] at this
      simp only [Bool.and_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq] at this
      obtain ⟨h1, h2⟩ := this
      refine ⟨fun hs => ?_, fun hd => ?_⟩
      · rcases h1 with h1 | h1
        · exact absurd hs h1
        · exact sentB_iff.mp h1
      · rcases h2 with h2 | h2
        · exact absurd hd h2
        · exact gotB_iff.mp h2
    · rintro ⟨hlt, hst, h⟩
      refine ⟨⟨hlt, hst⟩, fun k _ => ?_⟩
      cases hk : p.elems[k]? with
      | none => rfl
      | some e =>
        have := h k e hk
        simp only [Bool.and_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq]
        refine ⟨?_, ?_⟩
        · by_cases hs : e.src = some v
          · exact Or.inr (sentB_iff.mpr (this.1 hs))
          · exact Or.inl hs
        · by_cases hd : e.dst = some v
          · exact Or.inr (gotB_iff.mpr (this.2 hd))
          · exact Or.inl hd
  | read k =>
    simp only [enB, En]
    cases hk : p.elems[k]? with
    | none => simp
    | some e =>
      simp only [Bool.and_eq_true, Option.some.injEq, exists_eq_left', optB_iff]
      rw [prevB_iff (P := fun j => Label.read j ∈ F) (fun j => by simp)]
  | push k =>
    simp only [enB, En]
    cases hk : p.elems[k]? with
    | none => simp
    | some e =>
      simp only [Bool.and_eq_true, Option.some.injEq, exists_eq_left', List.contains_iff_mem]
      rw [prevB_iff (fun j => sentB_iff)]
      constructor
      · rintro ⟨⟨h1, h2⟩, h3⟩; exact ⟨h1, h2, h3⟩
      · rintro ⟨h1, h2, h3⟩; exact ⟨⟨h1, h2⟩, h3⟩
  | pull k =>
    simp only [enB, En]
    cases hk : p.elems[k]? with
    | none => simp
    | some e =>
      simp only [Bool.and_eq_true, Option.some.injEq, exists_eq_left', List.contains_iff_mem,
        optB_iff]
      rw [prevB_iff (fun j => gotB_iff)]
      constructor
      · rintro ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩; exact ⟨h1, h2, h3, h4⟩
      · rintro ⟨h1, h2, h3, h4⟩; exact ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩
  | xfer k =>
    simp only [enB, En]
    cases hk : p.elems[k]? with
    | none => simp
    | some e =>
      simp only [Bool.and_eq_true, Bool.not_eq_true', Option.some.injEq, exists_eq_left',
        List.contains_iff_mem, optB_iff]
      rw [prevB_iff (fun j => gotB_iff)]
      constructor
      · rintro ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩; exact ⟨h1, h2, h3, h4⟩
      · rintro ⟨h1, h2, h3, h4⟩; exact ⟨⟨⟨h1, h2⟩, h3⟩, h4⟩

/-- Every label that can ever fire. -/
def cands (p : Prog) : List Label :=
  (List.range p.graph.size).flatMap (fun v => [.start v, .finish v]) ++
    (List.range p.elems.size).flatMap fun k => [.read k, .push k, .pull k, .xfer k]

theorem elem_lt {k : Nat} {e : Elem} (h : p.elems[k]? = some e) : k < p.elems.size := by
  rcases Nat.lt_or_ge k p.elems.size with h' | h'
  · exact h'
  · simp [Array.getElem?_eq_none h'] at h

theorem mem_cands {F : List Label} {l : Label} (h : En p F l) : l ∈ cands p := by
  simp only [cands, List.mem_append, List.mem_flatMap, List.mem_range, List.mem_cons,
    List.not_mem_nil, or_false]
  cases l with
  | start v => exact Or.inl ⟨v, h.1, by simp⟩
  | finish v => exact Or.inl ⟨v, h.1, by simp⟩
  | read k => obtain ⟨e, hk, _⟩ := h; exact Or.inr ⟨k, elem_lt hk, by simp⟩
  | push k => obtain ⟨e, hk, _⟩ := h; exact Or.inr ⟨k, elem_lt hk, by simp⟩
  | pull k => obtain ⟨e, hk, _⟩ := h; exact Or.inr ⟨k, elem_lt hk, by simp⟩
  | xfer k => obtain ⟨e, hk, _⟩ := h; exact Or.inr ⟨k, elem_lt hk, by simp⟩

/-- A label that can fire next, if any. -/
def next? (p : Prog) (F : List Label) : Option Label :=
  (cands p).find? fun l => !F.contains l && enB p F l

/-- Fire enabled labels until none is (or the fuel runs out). Returns the fired labels, most
recent first. -/
def greedy (p : Prog) : Nat → List Label → List Label
  | 0, F => F
  | fuel + 1, F =>
    match next? p F with
    | none => F
    | some l => greedy p fuel (l :: F)

theorem greedy_run (fuel : Nat) {F₀ t F : List Label} (r : Run p F₀ t F) :
    ∃ t', Run p F₀ t' (greedy p fuel F) := by
  induction fuel generalizing t F with
  | zero => exact ⟨t, r⟩
  | succ fuel ih =>
    simp only [greedy]
    cases hn : next? p F with
    | none => exact ⟨t, r⟩
    | some l =>
      have := List.find?_some hn
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at this
      exact ih (r.append (enB_iff.mp this.2) (by simpa using this.1))

def doneB (p : Prog) (F : List Label) : Bool :=
  (List.range p.graph.size).all fun v => F.contains (.finish v)

theorem doneB_iff {F : List Label} : doneB p F = true ↔ Done p F := by
  simp [doneB, Done]

def stuckB (p : Prog) (F : List Label) : Bool :=
  (cands p).all fun l => F.contains l || !enB p F l

theorem stuck_of_stuckB {F : List Label} (h : stuckB p F = true) : Stuck p F := by
  intro l hn he
  simp only [stuckB, List.all_eq_true, Bool.or_eq_true, List.contains_iff_mem,
    Bool.not_eq_true'] at h
  rcases h l (mem_cands he) with h | h
  · exact hn h
  · rw [enB_iff.mpr he] at h; cases h

/-- Whether the program can run to completion: `some true` if it can, `some false` if it
cannot, `none` if the greedy run ran out of fuel (`check_some` rules that out). -/
def check (p : Prog) : Option Bool :=
  let F := greedy p ((cands p).length + 1) []
  if doneB p F then some true else if stuckB p F then some false else none

/-- **A `true` answer is right**: some execution completes. -/
theorem check_true (h : check p = some true) : ∃ t G, Run p [] t G ∧ Done p G := by
  simp only [check] at h
  obtain ⟨t, r⟩ := greedy_run (p := p) ((cands p).length + 1) (Run.nil [])
  split at h
  · next hd => exact ⟨t, _, r, doneB_iff.mp hd⟩
  · split at h <;> simp at h

/-- **A `false` answer is right**: no execution completes. Every execution deadlocks. -/
theorem check_false (h : check p = some false) : ¬ ∃ t G, Run p [] t G ∧ Done p G := by
  simp only [check] at h
  obtain ⟨t, r⟩ := greedy_run (p := p) ((cands p).length + 1) (Run.nil [])
  split at h
  · simp at h
  · next hnd =>
    split at h
    · next hst =>
      exact no_completion_of_stuck r (stuck_of_stuckB hst) (fun hd => hnd (doneB_iff.mpr hd))
    · simp at h

end Chan

end

end Veir.Air
