module

public import Veir.Air.ChanSem
public import Veir.Air.Determinism

namespace Veir.Air

@[expose] public section

/-! # Layer 4: memory through channels, races, determinism

The labels of `Veir.Air.ChanSem` act on memory:
- `read k` copies element `k`'s source location (or zero, for put padding, D31) into a slot of
  its own: the value in flight;
- `pull k i` copies the value in flight to element `k`'s destination at slot `i`; `xfer k` to its
  destinations at every slot at once (a broadcast, D29);
- `finish v` applies event `v`'s effect, as in `Veir.Air.Determinism` (D7): an `air.execute`
  body, a DMA, or a get's padding zeros (D31);
- `start v` and `push k` change nothing.

`HB` is the order every execution respects (`HB.before`). A program is race-free when any two
labels that touch a common location, one of them writing it, are ordered by `HB`.

- `deterministic`: in a race-free program whose effects are framed by their footprints, every
  complete execution ends with the same memory (C3 for channels).
- `racesL_nil`: the race checker, run on one complete execution, is sound.

D36 follows rather than being assumed:
- (b) a get's completion comes after the put's reads of what it got (`finish` needs `pull`/`xfer`,
  which need `read`);
- (a) a put may read element `i` before element `j < i` arrives, so it is ordered after that write
  only if `i ≤ j`.
-/

namespace Chan

variable {V : Type}

/-! ### Footprints and framing, per label -/

abbrev LFp := Label → List Access

def LReads (fp : LFp) (l : Label) (x : Loc) : Prop :=
  ∃ a ∈ fp l, a.kind = .read ∧ a.buf = x.1 ∧ x.2 ∈ a.elems

def LWrites (fp : LFp) (l : Label) (x : Loc) : Prop :=
  ∃ a ∈ fp l, a.kind = .write ∧ a.buf = x.1 ∧ x.2 ∈ a.elems

structure LFramed (fp : LFp) (eff : Label → Mem V → Mem V) : Prop where
  outside : ∀ l m x, ¬ LWrites fp l x → eff l m x = m x
  inputs : ∀ l m m', (∀ x, LReads fp l x → m x = m' x) → ∀ x, LWrites fp l x → eff l m x = eff l m' x

def LConflict (fp : LFp) (x y : Label) : Prop := ∃ a ∈ fp x, ∃ b ∈ fp y, a.Conflicts b

theorem LConflict.symm {fp : LFp} {x y : Label} (h : LConflict fp x y) : LConflict fp y x := by
  obtain ⟨a, ha, b, hb, h⟩ := h
  exact ⟨b, hb, a, ha, h.symm⟩

theorem effects_commuteL {fp : LFp} {eff : Label → Mem V → Mem V} (hfr : LFramed fp eff)
    {u v : Label} (hnc : ¬ LConflict fp u v) (m : Mem V) : eff u (eff v m) = eff v (eff u m) := by
  have ww : ∀ x, LWrites fp u x → LWrites fp v x → False := by
    rintro x ⟨a, ha, hak, hab, hax⟩ ⟨b, hb, _, hbb, hbx⟩
    exact hnc ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inl hak, x.2, hax, hbx⟩
  have wr : ∀ x, LWrites fp u x → LReads fp v x → False := by
    rintro x ⟨a, ha, hak, hab, hax⟩ ⟨b, hb, _, hbb, hbx⟩
    exact hnc ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inl hak, x.2, hax, hbx⟩
  have rw' : ∀ x, LReads fp u x → LWrites fp v x → False := by
    rintro x ⟨a, ha, _, hab, hax⟩ ⟨b, hb, hbk, hbb, hbx⟩
    exact hnc ⟨a, ha, b, hb, hab.trans hbb.symm, Or.inr hbk, x.2, hax, hbx⟩
  funext x
  by_cases hu : LWrites fp u x
  · have hv : ¬ LWrites fp v x := fun hv => ww x hu hv
    rw [hfr.outside v _ x hv]
    exact hfr.inputs u _ _ (fun y hr => hfr.outside v m y fun hw => rw' y hr hw) x hu
  · by_cases hv : LWrites fp v x
    · rw [hfr.outside u _ x hu]
      exact (hfr.inputs v _ _ (fun y hr => hfr.outside u m y fun hw => wr y hw hr) x hv).symm
    · rw [hfr.outside u _ x hu, hfr.outside v _ x hv, hfr.outside v _ x hv, hfr.outside u _ x hu]

def runL (eff : Label → Mem V → Mem V) (t : List Label) (m : Mem V) : Mem V :=
  t.foldl (fun m l => eff l m) m

/-! ### The memory semantics of labels -/

def upd (m : Mem V) (x : Loc) (a : V) : Mem V := fun y => if y = x then a else m y

/-- What a program's labels do to memory. -/
structure MemSpec (V : Type) where
  /-- Element `k`'s source location; `none` for put padding, which reads as `zero`. -/
  srcLoc : Nat → Option Loc
  /-- Element `k`'s destination location at slot `i`. -/
  dstLoc : Nat → Nat → Loc
  /-- How many slots element `k` has. -/
  nDst : Nat → Nat
  /-- Where element `k` is held in flight; not a location of any buffer. -/
  slot : Nat → Loc
  zero : V
  /-- Event `v`'s effect at its finish, and its footprint. -/
  evEff : Nat → Mem V → Mem V
  evFp : Nat → List Access

def acc (x : Loc) (k : AccessKind) : Access := ⟨x.1, k, [x.2]⟩

def MemSpec.eff (ms : MemSpec V) : Label → Mem V → Mem V
  | .start _ => id
  | .finish v => ms.evEff v
  | .read k => fun m => upd m (ms.slot k) (match ms.srcLoc k with | some x => m x | none => ms.zero)
  | .push _ => id
  | .pull k i => fun m => upd m (ms.dstLoc k i) (m (ms.slot k))
  | .xfer k => fun m y =>
    if (List.range (ms.nDst k)).any (fun i => decide (ms.dstLoc k i = y)) then m (ms.slot k) else m y

def MemSpec.fp (ms : MemSpec V) : LFp
  | .start _ => []
  | .finish v => ms.evFp v
  | .read k => acc (ms.slot k) .write :: (match ms.srcLoc k with | some x => [acc x .read] | none => [])
  | .push _ => []
  | .pull k i => [acc (ms.slot k) .read, acc (ms.dstLoc k i) .write]
  | .xfer k => acc (ms.slot k) .read :: (List.range (ms.nDst k)).map fun i => acc (ms.dstLoc k i) .write

theorem acc_loc {a : Access} {x y : Loc} {k : AccessKind} (ha : a = acc y k) (hab : a.buf = x.1)
    (hax : x.2 ∈ a.elems) : x = y := by
  subst ha
  simp only [acc, List.mem_singleton] at hab hax
  exact Prod.ext hab.symm hax

/-- Element labels are framed by their footprints; events are framed if their effects are. -/
theorem MemSpec.framed (ms : MemSpec V)
    (hout : ∀ v m x, ¬ (∃ a ∈ ms.evFp v, a.kind = .write ∧ a.buf = x.1 ∧ x.2 ∈ a.elems) →
      ms.evEff v m x = m x)
    (hin : ∀ v m m', (∀ x, (∃ a ∈ ms.evFp v, a.kind = .read ∧ a.buf = x.1 ∧ x.2 ∈ a.elems) →
      m x = m' x) → ∀ x, (∃ a ∈ ms.evFp v, a.kind = .write ∧ a.buf = x.1 ∧ x.2 ∈ a.elems) →
      ms.evEff v m x = ms.evEff v m' x) :
    LFramed ms.fp ms.eff := by
  constructor
  · intro l m x hw
    cases l with
    | start => rfl
    | finish v => exact hout v m x hw
    | read k =>
      simp only [MemSpec.eff, upd]
      have : x ≠ ms.slot k := fun h => hw ⟨acc (ms.slot k) .write, by simp [MemSpec.fp], rfl,
        by simp [acc, h], by simp [acc, h]⟩
      simp [this]
    | push => rfl
    | pull k i =>
      simp only [MemSpec.eff, upd]
      have : x ≠ ms.dstLoc k i := fun h => hw ⟨acc (ms.dstLoc k i) .write, by simp [MemSpec.fp], rfl,
        by simp [acc, h], by simp [acc, h]⟩
      simp [this]
    | xfer k =>
      simp only [MemSpec.eff]
      split
      · next hany =>
        exfalso
        simp only [List.any_eq_true, List.mem_range, decide_eq_true_eq] at hany
        obtain ⟨i, hi, rfl⟩ := hany
        have hmem : acc (ms.dstLoc k i) .write ∈ ms.fp (.xfer k) := by
          simp only [MemSpec.fp, List.mem_cons, List.mem_map, List.mem_range]
          exact Or.inr ⟨i, hi, rfl⟩
        exact hw ⟨acc (ms.dstLoc k i) .write, hmem, rfl, by simp [acc], by simp [acc]⟩
      · rfl
  · intro l m m' hr x hw
    cases l with
    | start => simp [LWrites, MemSpec.fp] at hw
    | finish v => exact hin v m m' hr x hw
    | read k =>
      simp only [MemSpec.eff, upd]
      split
      · cases hs : ms.srcLoc k with
        | none => rfl
        | some y =>
          exact hr y ⟨acc y .read, by simp [MemSpec.fp, hs], rfl, rfl, by simp [acc]⟩
      · next hne =>
        exfalso
        obtain ⟨a, ha, hak, hab, hax⟩ := hw
        simp only [MemSpec.fp, List.mem_cons] at ha
        rcases ha with ha | ha
        · exact hne (acc_loc ha hab hax)
        · cases hs : ms.srcLoc k with
          | none => simp [hs] at ha
          | some y => simp [hs, acc] at ha; subst ha; cases hak
    | push => simp [LWrites, MemSpec.fp] at hw
    | pull k i =>
      simp only [MemSpec.eff, upd]
      split
      · exact hr (ms.slot k) ⟨acc (ms.slot k) .read, by simp [MemSpec.fp], rfl, rfl, by simp [acc]⟩
      · next hne =>
        exfalso
        obtain ⟨a, ha, hak, hab, hax⟩ := hw
        simp only [MemSpec.fp, List.mem_cons, List.not_mem_nil, or_false] at ha
        rcases ha with ha | ha
        · subst ha; cases hak
        · exact hne (acc_loc ha hab hax)
    | xfer k =>
      simp only [MemSpec.eff]
      by_cases hc : ((List.range (ms.nDst k)).any fun i => decide (ms.dstLoc k i = x)) = true
      · rw [if_pos hc, if_pos hc]
        exact hr (ms.slot k) ⟨acc (ms.slot k) .read, by simp [MemSpec.fp], rfl, rfl, by simp [acc]⟩
      · next =>
        have hnone := hc
        exfalso
        obtain ⟨a, ha, hak, hab, hax⟩ := hw
        simp only [MemSpec.fp, List.mem_cons, List.mem_map, List.mem_range] at ha
        rcases ha with ha | ⟨i, hi, ha⟩
        · subst ha; cases hak
        · apply hnone
          simp only [List.any_eq_true, List.mem_range, decide_eq_true_eq]
          exact ⟨i, hi, (acc_loc ha.symm hab hax).symm⟩

/-! ### The order every execution respects -/

/-- The label that puts element `j` into the stream. -/
def sentLabel (p : Prog) (j : Nat) : Label :=
  match p.elems[j]? with
  | some e => if e.buffered then .push j else .xfer j
  | none => .push j

/-- The label that takes element `j` out of the stream at slot `i`. -/
def gotLabel (p : Prog) (j i : Nat) : Label :=
  match p.elems[j]? with
  | some e => if e.buffered then .pull j i else .xfer j
  | none => .pull j i

def optL (o : Option Nat) (f : Nat → Label) : List Label :=
  match o with
  | some j => [f j]
  | none => []

/-- What label `l` needs to have fired before it, in every execution. -/
def hbPreds (p : Prog) : Label → List Label
  | .start v => (p.graph.predsOf v).map .finish
  | .finish v => .start v :: (List.range p.elems.size).flatMap fun k =>
      match p.elems[k]? with
      | none => []
      | some e => (if e.src = some v then [sentLabel p k] else []) ++
          (List.range e.dsts.length).filterMap fun i =>
            if e.dsts[i]? = some (some v) then some (gotLabel p k i) else none
  | .read k =>
    match p.elems[k]? with
    | none => []
    | some e => optL e.src .start ++ optL e.prev .read
  | .push k =>
    match p.elems[k]? with
    | none => []
    | some e => .read k :: optL e.prev (sentLabel p)
  | .pull k i =>
    match p.elems[k]? with
    | none => []
    | some e => .push k :: (match e.dsts[i]? with | some (some d) => [.start d] | _ => []) ++
        optL e.prev (fun j => gotLabel p j i)
  | .xfer k =>
    match p.elems[k]? with
    | none => []
    | some e => .read k :: (e.dsts.filterMap id).map .start ++
        (match e.prev with | some j => (List.range e.dsts.length).map (gotLabel p j) | none => [])

/-- Every fired label was enabled; by `En.mono`, it still is. -/
def Inv (p : Prog) (F : List Label) : Prop := ∀ x ∈ F, En p F x

theorem Inv.nil {p : Prog} : Inv p [] := fun _ h => absurd h (by simp)

theorem Inv.cons {p : Prog} {F : List Label} {l : Label} (hi : Inv p F) (he : En p F l) :
    Inv p (l :: F) := by
  have s : Sub F (l :: F) := fun x hx => List.mem_cons_of_mem _ hx
  intro x hx
  simp only [List.mem_cons] at hx
  rcases hx with rfl | hx
  · exact he.mono s
  · exact (hi x hx).mono s

theorem Run.inv {p : Prog} {F t G : List Label} (r : Run p F t G) (hi : Inv p F) : Inv p G := by
  induction r with
  | nil => exact hi
  | cons he _ _ ih => exact ih (hi.cons he)

variable {p : Prog}

theorem sent_label {F : List Label} {j : Nat} (hi : Inv p F) (h : Sent F j) : sentLabel p j ∈ F := by
  rcases h with h | h
  · obtain ⟨e, hj, hb, _⟩ := hi _ h
    simp [sentLabel, hj, hb, h]
  · obtain ⟨e, hj, hb, _⟩ := hi _ h
    simp [sentLabel, hj, hb, h]

theorem got_label {F : List Label} {j i : Nat} (hi : Inv p F) (h : Got F j i) : gotLabel p j i ∈ F := by
  rcases h with h | h
  · obtain ⟨e, hj, hb, _⟩ := hi _ h
    simp [gotLabel, hj, hb, h]
  · obtain ⟨e, hj, hb, _⟩ := hi _ h
    simp [gotLabel, hj, hb, h]

theorem mem_optL {o : Option Nat} {f : Nat → Label} {z : Label} (h : z ∈ optL o f) :
    ∃ j, o = some j ∧ z = f j := by
  unfold optL at h
  split at h <;> simp_all

/-- **What `hbPreds` lists has fired** whenever a label is enabled. -/
theorem hb_sound {F : List Label} {l : Label} (hi : Inv p F) (he : En p F l) :
    ∀ z ∈ hbPreds p l, z ∈ F := by
  intro z hz
  cases l with
  | start v =>
    simp only [hbPreds, List.mem_map] at hz
    obtain ⟨u, hu, rfl⟩ := hz
    exact he.2 u hu
  | finish v =>
    obtain ⟨_, hst, hel⟩ := he
    simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range] at hz
    rcases hz with rfl | ⟨k, _, hz⟩
    · exact hst
    · cases hk : p.elems[k]? with
      | none => simp [hk] at hz
      | some e =>
        simp only [hk, List.mem_append] at hz
        rcases hz with hz | hz
        · split at hz
          · next hs => simp only [List.mem_singleton] at hz; subst hz
                       exact sent_label hi ((hel k e hk).1 hs)
          · simp at hz
        · simp only [List.mem_filterMap, List.mem_range] at hz
          obtain ⟨i, _, hz⟩ := hz
          split at hz
          · next hd => simp only [Option.some.injEq] at hz; subst hz
                       exact got_label hi ((hel k e hk).2 i hd)
          · simp at hz
  | read k =>
    obtain ⟨e, hk, ⟨s, hs, hss⟩, hprev⟩ := he
    simp only [hbPreds, hk, List.mem_append] at hz
    rcases hz with hz | hz
    · obtain ⟨j, hj, rfl⟩ := mem_optL hz
      rw [hs] at hj; cases hj; exact hss
    · obtain ⟨j, hj, rfl⟩ := mem_optL hz
      exact hprev j hj
  | push k =>
    obtain ⟨e, hk, _, hr, hprev⟩ := he
    simp only [hbPreds, hk, List.mem_cons] at hz
    rcases hz with rfl | hz
    · exact hr
    · obtain ⟨j, hj, rfl⟩ := mem_optL hz
      exact sent_label hi (hprev j hj)
  | pull k i =>
    obtain ⟨e, hk, _, ⟨d, hd, hds⟩, hpu, hprev⟩ := he
    simp only [hbPreds, hk, hd, List.mem_cons, List.mem_append, List.not_mem_nil, or_false] at hz
    rcases hz with (rfl | rfl) | hz
    · exact hpu
    · exact hds
    · obtain ⟨j, hj, rfl⟩ := mem_optL hz
      exact got_label hi (hprev j hj)
  | xfer k =>
    obtain ⟨e, hk, _, hr, ⟨_, hall⟩, hprev⟩ := he
    simp only [hbPreds, hk, List.mem_cons, List.mem_append, List.mem_map, List.mem_filterMap,
      id_eq] at hz
    rcases hz with (rfl | ⟨d, hd, rfl⟩) | hz
    · exact hr
    · obtain ⟨o, ho, hod⟩ := hd
      obtain ⟨d', hd', hds⟩ := hall o ho
      rw [hod] at hd'; cases hd'; exact hds
    · cases hp : e.prev with
      | none => simp [hp] at hz
      | some j =>
        simp only [hp, List.mem_map, List.mem_range] at hz
        obtain ⟨i, hi', rfl⟩ := hz
        exact got_label hi (hprev j hp i hi')

/-- `HB p x y`: `x` has fired whenever `y` has, in every execution. -/
inductive HB (p : Prog) : Label → Label → Prop
  | refl (x : Label) : HB p x x
  | step {x z y : Label} : HB p x z → z ∈ hbPreds p y → HB p x y

theorem HB.fired {F : List Label} {x y : Label} (hi : Inv p F) (h : HB p x y) (hy : y ∈ F) :
    x ∈ F := by
  induction h with
  | refl => exact hy
  | step _ hz ih => exact ih (hb_sound hi (hi _ hy) _ hz)

/-- **Every execution respects `HB`**: when `y` fires, every other `x` with `HB p x y` already has. -/
theorem HB.before {F : List Label} {x y : Label} (hi : Inv p F) (h : HB p x y) (hne : x ≠ y)
    (he : En p F y) : x ∈ F := by
  cases h with
  | refl => exact absurd rfl hne
  | step h hz => exact h.fired hi (hb_sound hi he _ hz)

/-- Every pair of distinct labels of `S` that touch a common location, one writing, is ordered. -/
def RaceFree (p : Prog) (fp : LFp) (S : Label → Prop) : Prop :=
  ∀ x y, S x → S y → x ≠ y → LConflict fp x y → HB p x y ∨ HB p y x

/-! ### Determinism -/

theorem Run.nodup {F t G : List Label} (r : Run p F t G) : t.Nodup := by
  induction r with
  | nil => exact List.nodup_nil
  | cons _ _ rest ih =>
    exact List.nodup_cons.mpr ⟨fun h => rest.not_mem _ h (List.mem_cons_self ..), ih⟩

/-- In an execution, a label `x` that needs `a` comes after `a`. -/
theorem Run.hb_prefix {F t G : List Label} {a x : Label} (r : Run p F t G) (hi : Inv p F)
    (hb : HB p a x) (hne : a ≠ x) :
    ∀ t₁ t₂, t = t₁ ++ x :: t₂ → a ∈ F ∨ a ∈ t₁ := by
  induction r with
  | nil => intro t₁ t₂ h; simp at h
  | @cons F l t G he hn rest ih =>
    intro t₁ t₂ h
    cases t₁ with
    | nil =>
      simp only [List.nil_append, List.cons.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact Or.inl (hb.before hi hne he)
    | cons y t₁ =>
      simp only [List.cons_append, List.cons.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      rcases ih (hi.cons he) t₁ t₂ rfl with h | h
      · simp only [List.mem_cons] at h
        rcases h with rfl | h
        · exact Or.inr (List.mem_cons_self ..)
        · exact Or.inl h
      · exact Or.inr (List.mem_cons_of_mem _ h)

/-- Runs only depend on which labels have fired. -/
theorem Run.congr {F F' t G : List Label} (r : Run p F t G) (h : ∀ y, y ∈ F ↔ y ∈ F') :
    ∃ G', Run p F' t G' := by
  induction r generalizing F' with
  | nil => exact ⟨_, .nil _⟩
  | @cons F l t G he hn _ ih =>
    obtain ⟨G', r'⟩ := ih (F' := l :: F') (fun y => by simp only [List.mem_cons, h y])
    exact ⟨G', .cons (he.mono fun y hy => (h y).mp hy) (fun h' => hn ((h l).mpr h')) r'⟩

/-- Run `a` first instead: everything still fires after what it needs. -/
theorem Run.remove {F xs ys G : List Label} {a : Label} (r : Run p F (xs ++ a :: ys) G)
    (he : En p F a) (hn : a ∉ F) : ∃ G', Run p (a :: F) (xs ++ ys) G' := by
  induction xs generalizing F with
  | nil =>
    cases r with
    | cons _ _ rest => exact ⟨_, rest⟩
  | cons x xs ih =>
    cases r with
    | cons hx hxn rest =>
      have hxa : x ≠ a := by
        intro h; subst h
        exact rest.not_mem x (List.mem_append_right _ (List.mem_cons_self ..)) (List.mem_cons_self ..)
      obtain ⟨G', r'⟩ := ih rest (he.mono fun y hy => List.mem_cons_of_mem _ hy)
        (by simp only [List.mem_cons, not_or]; exact ⟨Ne.symm hxa, hn⟩)
      -- `r'` runs from `a :: x :: F`; reorder to `x :: a :: F`.
      obtain ⟨G'', r''⟩ := Run.congr r' (F' := x :: a :: F) (fun y => by
        simp only [List.mem_cons]
        constructor
        · rintro (h | h | h) <;> simp [h]
        · rintro (h | h | h) <;> simp [h])
      exact ⟨G'', .cons (hx.mono fun y hy => List.mem_cons_of_mem _ hy)
        (by simp only [List.mem_cons, not_or]; exact ⟨hxa, hxn⟩) r''⟩

theorem runL_bubble {eff : Label → Mem V → Mem V} {a : Label} {xs ys : List Label}
    (hcomm : ∀ x ∈ xs, ∀ m, eff a (eff x m) = eff x (eff a m)) (m : Mem V) :
    runL eff (xs ++ a :: ys) m = runL eff (a :: (xs ++ ys)) m := by
  induction xs generalizing m with
  | nil => rfl
  | cons x xs ih =>
    simp only [runL, List.cons_append, List.foldl_cons] at ih ⊢
    rw [ih (fun x' hx' => hcomm x' (List.mem_cons_of_mem _ hx')) (eff x m)]
    rw [hcomm x (List.mem_cons_self ..) m]

/-- Two executions of the same labels from the same state give the same memory, if every pair of
conflicting labels among them is ordered. -/
theorem runL_eq {fp : LFp} {eff : Label → Mem V → Mem V} {S : Label → Prop}
    (hfr : LFramed fp eff) (hrf : RaceFree p fp S) :
    ∀ (t₁ t₂ F G₁ G₂ : List Label) (m : Mem V), Inv p F → Run p F t₁ G₁ → Run p F t₂ G₂ →
      (∀ x, x ∈ t₁ ↔ x ∈ t₂) → (∀ x ∈ t₁, S x) → runL eff t₁ m = runL eff t₂ m := by
  intro t₁
  induction t₁ with
  | nil =>
    intro t₂ F G₁ G₂ m _ _ _ hsame _
    cases t₂ with
    | nil => rfl
    | cons y _ => exact absurd ((hsame y).mpr (List.mem_cons_self ..)) (by simp)
  | cons a r₁ ih =>
    intro t₂ F G₁ G₂ m hi h₁ h₂ hsame hS
    cases h₁ with
    | cons hae han hr₁ =>
      obtain ⟨xs, ys, rfl⟩ := List.append_of_mem ((hsame a).mp (List.mem_cons_self ..))
      have hnd₂ := h₂.nodup
      have haxs : a ∉ xs := by
        intro hax
        exact (List.nodup_append.mp hnd₂).2.2 a hax a (List.mem_cons_self ..) rfl
      have haxys : a ∉ xs ++ ys := by
        intro h
        simp only [List.mem_append] at h
        rcases h with h | h
        · exact haxs h
        · exact (List.nodup_cons.mp (List.nodup_append.mp hnd₂).2.1).1 h
      have hcomm : ∀ x ∈ xs, ∀ m, eff a (eff x m) = eff x (eff a m) := by
        intro x hx m
        have hxa : x ≠ a := fun h => haxs (h ▸ hx)
        have hxl₂ : x ∈ xs ++ a :: ys := List.mem_append_left _ hx
        have hxS : S x := hS x ((hsame x).mpr hxl₂)
        apply effects_commuteL hfr
        intro hconf
        rcases hrf a x (hS a (List.mem_cons_self ..)) hxS (Ne.symm hxa) hconf with hb | hb
        · -- `x` needs `a`, but runs before it in the second execution.
          obtain ⟨xs₁, xs₂, rfl⟩ := List.append_of_mem hx
          rcases h₂.hb_prefix hi hb (Ne.symm hxa) xs₁ (xs₂ ++ a :: ys) (by simp) with h | h
          · exact han h
          · exact haxs (List.mem_append_left _ h)
        · -- `a` needs `x`, so `x` fired before the first execution's first step.
          exact h₂.not_mem x hxl₂ (hb.before hi hxa hae)
      rw [runL_bubble hcomm]
      simp only [runL, List.foldl_cons]
      obtain ⟨G', r₂⟩ := h₂.remove hae han
      apply ih (xs ++ ys) (a :: F) G₁ G' (eff a m) (hi.cons hae) hr₁ r₂
      · intro v
        have har₁ : a ∉ r₁ := fun h => hr₁.not_mem a h (List.mem_cons_self ..)
        by_cases hva : v = a
        · subst hva; exact ⟨fun h => absurd h har₁, fun h => absurd h haxys⟩
        · have := hsame v
          simp only [List.mem_cons, hva, false_or, List.mem_append] at this ⊢
          exact this
      · exact fun x hx => hS x (List.mem_cons_of_mem _ hx)

/-! ### Every complete execution fires the same labels -/

/-- The labels a complete execution fires. -/
def Needed (p : Prog) : Label → Prop
  | .start v | .finish v => v < p.graph.size
  | .read k => ∃ e, p.elems[k]? = some e ∧ e.src.isSome
  | .push k => ∃ e, p.elems[k]? = some e ∧ e.buffered = true ∧ e.src.isSome
  | .pull k i => ∃ e, p.elems[k]? = some e ∧ e.buffered = true ∧ e.src.isSome ∧
      ∃ d, e.dsts[i]? = some (some d)
  | .xfer k => ∃ e, p.elems[k]? = some e ∧ e.buffered = false ∧ e.src.isSome ∧ e.dsts ≠ [] ∧
      ∀ o ∈ e.dsts, o.isSome

theorem needed_of_en {F : List Label} {l : Label} (hi : Inv p F) (he : En p F l) : Needed p l := by
  cases l with
  | start v => exact he.1
  | finish v => exact he.1
  | read k =>
    obtain ⟨e, hk, ⟨s, hs, _⟩, _⟩ := he
    exact ⟨e, hk, by simp [hs]⟩
  | push k =>
    obtain ⟨e, hk, hb, hr, _⟩ := he
    obtain ⟨e', hk', ⟨s, hs, _⟩, _⟩ := hi _ hr
    rw [hk] at hk'; cases hk'
    exact ⟨e, hk, hb, by simp [hs]⟩
  | pull k i =>
    obtain ⟨e, hk, hb, ⟨d, hd, _⟩, hpu, _⟩ := he
    obtain ⟨e', hk', _, hr, _⟩ := hi _ hpu
    obtain ⟨e'', hk'', ⟨s, hs, _⟩, _⟩ := hi _ hr
    rw [hk] at hk' hk''; cases hk'; cases hk''
    exact ⟨e, hk, hb, by simp [hs], d, hd⟩
  | xfer k =>
    obtain ⟨e, hk, hb, hr, ⟨hne, hall⟩, _⟩ := he
    obtain ⟨e', hk', ⟨s, hs, _⟩, _⟩ := hi _ hr
    rw [hk] at hk'; cases hk'
    refine ⟨e, hk, hb, by simp [hs], hne, fun o ho => ?_⟩
    obtain ⟨d, rfl, _⟩ := hall o ho
    rfl

/-- Every element's put and get are events of the program. -/
def WF (p : Prog) : Prop :=
  ∀ (k : Nat) (e : Elem), p.elems[k]? = some e → (∀ s, e.src = some s → s < p.graph.size) ∧
    (∀ (i d : Nat), e.dsts[i]? = some (some d) → d < p.graph.size)

theorem fired_of_needed {F : List Label} {l : Label} (hw : WF p) (hi : Inv p F) (hd : Done p F)
    (hn : Needed p l) : l ∈ F := by
  have sent : ∀ k e, p.elems[k]? = some e → e.src.isSome → Sent F k := by
    intro k e hk hs
    obtain ⟨s, hs⟩ := Option.isSome_iff_exists.mp hs
    exact ((hi _ (hd s ((hw k e hk).1 s hs))).2.2 k e hk).1 hs
  have got : ∀ (k : Nat) (e : Elem) (i d : Nat), p.elems[k]? = some e → e.dsts[i]? = some (some d) → Got F k i := by
    intro k e i d hk hd'
    exact ((hi _ (hd d ((hw k e hk).2 i d hd'))).2.2 k e hk).2 i hd'
  cases l with
  | start v => exact (hi _ (hd v hn)).2.1
  | finish v => exact hd v hn
  | read k =>
    obtain ⟨e, hk, hs⟩ := hn
    rcases sent k e hk hs with h | h
    · obtain ⟨_, _, _, hr, _⟩ := hi _ h; exact hr
    · obtain ⟨_, _, _, hr, _⟩ := hi _ h; exact hr
  | push k =>
    obtain ⟨e, hk, hb, hs⟩ := hn
    rcases sent k e hk hs with h | h
    · exact h
    · obtain ⟨e', hk', hb', _⟩ := hi _ h
      rw [hk] at hk'; cases hk'; rw [hb] at hb'; cases hb'
  | pull k i =>
    obtain ⟨e, hk, hb, _, d, hd'⟩ := hn
    rcases got k e i d hk hd' with h | h
    · exact h
    · obtain ⟨e', hk', hb', _⟩ := hi _ h
      rw [hk] at hk'; cases hk'; rw [hb] at hb'; cases hb'
  | xfer k =>
    obtain ⟨e, hk, hb, hs, _⟩ := hn
    rcases sent k e hk hs with h | h
    · obtain ⟨e', hk', hb', _⟩ := hi _ h
      rw [hk] at hk'; cases hk'; rw [hb] at hb'; cases hb'
    · exact h

/-- **Race-free channel programs are deterministic.** Every complete execution from the same
memory ends with the same memory, when every pair of conflicting labels of a complete execution
is ordered by `HB` and effects are framed by footprints. -/
theorem deterministic {fp : LFp} {eff : Label → Mem V → Mem V} (hw : WF p)
    (hfr : LFramed fp eff) {t₁ t₂ G₁ G₂ : List Label}
    (h₁ : Run p [] t₁ G₁) (d₁ : Done p G₁) (h₂ : Run p [] t₂ G₂) (d₂ : Done p G₂)
    (hrf : RaceFree p fp (· ∈ t₁)) (m : Mem V) :
    runL eff t₁ m = runL eff t₂ m := by
  have i₁ := h₁.inv Inv.nil
  have i₂ := h₂.inv Inv.nil
  have mem₁ : ∀ x, x ∈ G₁ ↔ x ∈ t₁ := fun x => by simpa using h₁.mem x
  have mem₂ : ∀ x, x ∈ G₂ ↔ x ∈ t₂ := fun x => by simpa using h₂.mem x
  apply runL_eq hfr hrf t₁ t₂ [] G₁ G₂ m Inv.nil h₁ h₂ _ (fun x hx => hx)
  intro x
  rw [← mem₁, ← mem₂]
  constructor
  · intro hx; exact fired_of_needed hw i₂ d₂ (needed_of_en i₁ (i₁ x hx))
  · intro hx; exact fired_of_needed hw i₁ d₁ (needed_of_en i₂ (i₂ x hx))

/-! ### Checking race freedom on one complete execution

Number the labels of a complete execution `t` by their positions. Every `hbPreds` edge then goes
backwards, so the graph is forward and its reachability is decided by `DepGraph.reachFast`
(`reachFast_eq`, `reach_of_reachB`). By `deterministic`, the labels of `t` are those of every
complete execution, so checking them is enough. -/

/-- `hbPreds` on the positions of `t`. -/
def posGraph (p : Prog) (t : List Label) : DepGraph :=
  ⟨(t.map fun l => (hbPreds p l).filterMap fun z =>
    if t.contains z then some (t.idxOf z) else none).toArray⟩

def conflictB (fp : LFp) (x y : Label) : Bool :=
  (fp x).any fun a => (fp y).any fun b => a.conflictsB b

theorem conflictB_iff {fp : LFp} {x y : Label} : conflictB fp x y = true ↔ LConflict fp x y := by
  simp [conflictB, LConflict, List.any_eq_true, Access.conflictsB_iff]

/-- The pairs of positions `i < j` of `t` whose labels conflict and are not ordered. -/
def racesL (p : Prog) (fp : LFp) (t : List Label) : List (Nat × Nat) :=
  let g := posGraph p t
  let rows := g.reachRows
  let arr := t.toArray
  (List.range arr.size).flatMap fun j =>
    (List.range j).filterMap fun i =>
      match arr[i]?, arr[j]? with
      | some x, some y =>
        if conflictB fp x y && !g.reachFast rows i j && !g.reachFast rows j i then some (i, j)
        else none
      | _, _ => none

theorem predsOf_posGraph {t : List Label} {b w : Nat} (h : w ∈ (posGraph p t).predsOf b) :
    ∃ y z, t[b]? = some y ∧ z ∈ hbPreds p y ∧ t[w]? = some z := by
  simp only [DepGraph.predsOf, posGraph, List.getElem?_toArray, List.getElem?_map] at h
  cases hb : t[b]? with
  | none => simp [hb] at h
  | some y =>
    simp only [hb, Option.map_some, Option.getD_some, List.mem_filterMap] at h
    obtain ⟨z, hz, hw⟩ := h
    split at hw
    · next hc =>
      simp only [Option.some.injEq] at hw
      subst hw
      have hzt : z ∈ t := by simpa using hc
      refine ⟨y, z, rfl, hz, ?_⟩
      rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hzt), List.getElem_idxOf]
    · simp at hw

theorem reach_hb {t : List Label} {a b : Nat} (r : DepGraph.Reach (posGraph p t) a b) :
    ∀ y, t[b]? = some y → ∃ x, t[a]? = some x ∧ HB p x y := by
  induction r with
  | refl => intro y hy; exact ⟨y, hy, .refl y⟩
  | @step w v _ hp ih =>
    intro y hy
    obtain ⟨y', z, hy', hz, hw⟩ := predsOf_posGraph hp
    rw [hy] at hy'; cases hy'
    obtain ⟨x, hx, hxz⟩ := ih z hw
    exact ⟨x, hx, .step hxz hz⟩

/-- **The race checker is sound**: no reported pair means race-free. -/
theorem raceFree_of_racesL {fp : LFp} {t : List Label} (h : racesL p fp t = []) :
    RaceFree p fp (· ∈ t) := by
  intro x y hx hy hne hc
  have hi := List.idxOf_lt_length_of_mem hx
  have hj := List.idxOf_lt_length_of_mem hy
  have gx : t[t.idxOf x]? = some x := by
    rw [List.getElem?_eq_getElem hi, List.getElem_idxOf]
  have gy : t[t.idxOf y]? = some y := by
    rw [List.getElem?_eq_getElem hj, List.getElem_idxOf]
  have hij : t.idxOf x ≠ t.idxOf y := fun e => hne (by rw [e] at gx; rw [gx] at gy; cases gy; rfl)
  -- The pair (min, max) of the two positions was checked and not reported.
  have key : ∀ i j u w, i < j → j < t.length → t[i]? = some u → t[j]? = some w →
      LConflict fp u w → (DepGraph.Reach (posGraph p t) i j ∨ DepGraph.Reach (posGraph p t) j i) := by
    intro i j u w hij hj hu hw hcf
    have hnot : (i, j) ∉ racesL p fp t := by rw [h]; simp
    simp only [racesL, List.mem_flatMap, List.mem_range, List.mem_filterMap, List.size_toArray,
      List.getElem?_toArray, not_exists, not_and] at hnot
    have := hnot j hj i hij
    rw [hu, hw] at this
    simp only [conflictB_iff.mpr hcf, Bool.true_and, DepGraph.reachFast_eq] at this
    by_cases r1 : (posGraph p t).reachB i j = true
    · exact Or.inl (DepGraph.reach_of_reachB r1)
    · by_cases r2 : (posGraph p t).reachB j i = true
      · exact Or.inr (DepGraph.reach_of_reachB r2)
      · simp [r1, r2] at this
  rcases Nat.lt_or_gt_of_ne hij with hlt | hlt
  · rcases key _ _ x y hlt hj gx gy hc with r | r
    · obtain ⟨x', hx', hb⟩ := reach_hb r y gy
      rw [gx] at hx'; cases hx'; exact Or.inl hb
    · obtain ⟨y', hy', hb⟩ := reach_hb r x gx
      rw [gy] at hy'; cases hy'; exact Or.inr hb
  · rcases key _ _ y x hlt hi gy gx hc.symm with r | r
    · obtain ⟨y', hy', hb⟩ := reach_hb r x gx
      rw [gy] at hy'; cases hy'; exact Or.inr hb
    · obtain ⟨x', hx', hb⟩ := reach_hb r y gy
      rw [gx] at hx'; cases hx'; exact Or.inl hb

/-! ### The whole check -/

/-- The fired labels of the greedy execution, in firing order. -/
def trace (p : Prog) : List Label := (greedy p ((cands p).length + 1) []).reverse

theorem greedy_rev (fuel : Nat) {F : List Label} (h : Run p [] F.reverse F) :
    Run p [] (greedy p fuel F).reverse (greedy p fuel F) := by
  induction fuel generalizing F with
  | zero => exact h
  | succ fuel ih =>
    simp only [greedy]
    cases hn : next? p F with
    | none => exact h
    | some l =>
      have := List.find?_some hn
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at this
      apply ih
      simpa using h.append (enB_iff.mp this.2) (by simpa using this.1)

theorem run_trace : Run p [] (trace p) (greedy p ((cands p).length + 1) []) :=
  greedy_rev _ (Run.nil [])

/-- **What the whole check buys.** If the greedy execution completes and has no race, then every
complete execution of the program ends with the memory the greedy one ends with. -/
theorem outcome_unique {fp : LFp} {eff : Label → Mem V → Mem V} (hw : WF p)
    (hfr : LFramed fp eff) (hd : doneB p (greedy p ((cands p).length + 1) []) = true)
    (hr : racesL p fp (trace p) = []) {t G : List Label} (h : Run p [] t G) (d : Done p G)
    (m : Mem V) : runL eff t m = runL eff (trace p) m :=
  (deterministic hw hfr run_trace (doneB_iff.mp hd) h d (raceFree_of_racesL hr) m).symm

end Chan

end

end Veir.Air
