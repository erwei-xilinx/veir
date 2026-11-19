module

public import Veir.Air.ChanEventReach

namespace Veir.Air

@[expose] public section

/-! # D59: control flow decided by values events compute

A loop bound or branch condition computed by an event is read by a *decision*: a label that reads
the event's result (D60: a blocking op, ordered after the event only by tokens, as D45 and D57).
The program is instantiated with a guessed value for each decision (`ChanGlue`, not proven); this
file proves when the guess is right in every execution.

Results live in a buffer `B` of their own (`IProgram.resultBuf`): location `(B, v)` holds event
`v`'s results, written by `finish v` and by nothing else (`soleWritersB`). If the checked execution
`t` completes and is race-free, and fires `finish v` before the decision `y`, then:
- `value_after_writer`: in every execution, partial or complete, once `finish v` has fired,
  `(B, v)` holds what it holds at the end of `t`;
- `decision_reads`: in every execution, when `y` fires, `(B, v)` holds what it holds at the end
  of `t`. So if the instantiation guessed that value, the guess is what every execution reads.
-/

namespace Chan

variable {V : Type} {p : Prog}

namespace Run

theorem trans {F t H u G : List Label} (r₁ : Run p F t H) (r₂ : Run p H u G) :
    Run p F (t ++ u) G := by
  induction r₁ with
  | nil => exact r₂
  | cons he hn _ ih => exact .cons he hn (ih r₂)

theorem split {F t₁ t₂ G : List Label} (r : Run p F (t₁ ++ t₂) G) :
    ∃ H, Run p F t₁ H ∧ Run p H t₂ G := by
  induction t₁ generalizing F with
  | nil => exact ⟨F, .nil F, r⟩
  | cons l t₁ ih =>
    cases r with
    | cons he hn rest =>
      obtain ⟨H, r₁, r₂⟩ := ih rest
      exact ⟨H, .cons he hn r₁, r₂⟩

/-- Every label a run fires is a candidate. -/
theorem mem_cands' {F t G : List Label} (r : Run p F t G) : ∀ z ∈ t, z ∈ cands p := by
  induction r with
  | nil => simp
  | cons he _ _ ih =>
    intro z hz
    simp only [List.mem_cons] at hz
    rcases hz with rfl | hz
    · exact mem_cands he
    · exact ih z hz

end Run

theorem runL_append (eff : Label → Mem V → Mem V) (t u : List Label) (m : Mem V) :
    runL eff (t ++ u) m = runL eff u (runL eff t m) := by
  simp [runL, List.foldl_append]

/-- Labels that do not write a location leave it alone. -/
theorem runL_outside {fp : LFp} {eff : Label → Mem V → Mem V} (hfr : LFramed fp eff) {x : Loc} :
    ∀ (u : List Label) (m : Mem V), (∀ l ∈ u, ¬ LWrites fp l x) → runL eff u m x = m x := by
  intro u
  induction u with
  | nil => intro m _; rfl
  | cons l u ih =>
    intro m h
    simp only [runL, List.foldl_cons] at ih ⊢
    rw [ih (eff l m) (fun z hz => h z (List.mem_cons_of_mem _ hz))]
    exact hfr.outside l m x (h l (List.mem_cons_self ..))

/-! ### A buffer of results -/

/-- Whether `l` writes location `x`. -/
def lwritesB (fp : LFp) (l : Label) (x : Loc) : Bool :=
  (fp l).any fun a => a.kind == .write && a.buf == x.1 && a.elems.contains x.2

theorem lwritesB_iff {fp : LFp} {l : Label} {x : Loc} : lwritesB fp l x = true ↔ LWrites fp l x := by
  simp only [lwritesB, List.any_eq_true, Bool.and_eq_true, beq_iff_eq, List.contains_iff_mem,
    LWrites]
  constructor
  · rintro ⟨a, ha, ⟨hk, hb⟩, he⟩; exact ⟨a, ha, hk, hb, he⟩
  · rintro ⟨a, ha, hk, hb, he⟩; exact ⟨a, ha, ⟨hk, hb⟩, he⟩

/-- Whether `l` reads location `x`. -/
def lreadsB (fp : LFp) (l : Label) (x : Loc) : Bool :=
  (fp l).any fun a => a.kind == .read && a.buf == x.1 && a.elems.contains x.2

theorem lreadsB_iff {fp : LFp} {l : Label} {x : Loc} : lreadsB fp l x = true ↔ LReads fp l x := by
  simp only [lreadsB, List.any_eq_true, Bool.and_eq_true, beq_iff_eq, List.contains_iff_mem,
    LReads]
  constructor
  · rintro ⟨a, ha, ⟨hk, hb⟩, he⟩; exact ⟨a, ha, hk, hb, he⟩
  · rintro ⟨a, ha, hk, hb, he⟩; exact ⟨a, ha, ⟨hk, hb⟩, he⟩

/-- In buffer `B`, among the labels `cs`, only `finish v` writes, and only location `(B, v)`. -/
def soleWritersB (fp : LFp) (cs : List Label) (B : Nat) : Bool :=
  cs.all fun z => (fp z).all fun a =>
    !(a.kind == .write && a.buf == B) ||
      match z with
      | .finish v => a.elems.all (· == Int.ofNat v)
      | _ => false

theorem soleWriters_spec {fp : LFp} {cs : List Label} {B : Nat} (h : soleWritersB fp cs B = true)
    {z : Label} (hz : z ∈ cs) {v : Nat} (hw : LWrites fp z (B, Int.ofNat v)) : z = .finish v := by
  simp only [soleWritersB, List.all_eq_true] at h
  obtain ⟨a, ha, hk, hb, he⟩ := hw
  have := h z hz a ha
  simp only [hk, hb, beq_self_eq_true, Bool.and_self, Bool.not_true, Bool.false_or] at this
  split at this
  · next w =>
    simp only [List.all_eq_true, beq_iff_eq] at this
    have h' : Int.ofNat v = Int.ofNat w := this _ he
    rw [Int.ofNat.inj h']
  · simp at this

/-! ### What a result holds -/

section
variable {fp : LFp} {eff : Label → Mem V → Mem V} {idx : Array (List Nat)}
  {ix : Std.HashMap Label Nat} {t : List Label}

/-- **A result, once written, is the complete execution `t`'s**, when the program is race-free
on its labels: in every execution, partial or complete, in which `finish v` has fired, location
`(B, v)` holds what `t` ends with. -/
theorem value_after_writerRF (hw : wfB p = true) (hfr : LFramed fp eff) {G₀ : List Label}
    (r₀ : Run p [] t G₀) (d₀ : Done p G₀) (hrf : RaceFree p fp (· ∈ t))
    {B : Nat} (hB : soleWritersB fp (cands p) B = true) {v : Nat}
    {s F : List Label} (hs : Run p [] s F) (hx : Label.finish v ∈ s) (m : Mem V) :
    runL eff s m (B, Int.ofNat v) = runL eff t m (B, Int.ofNat v) := by
  obtain ⟨u, H, ru, dH⟩ := completes_from_anywhere r₀ d₀ hs
  have whole := (deterministic (wf_of_wfB hw) hfr r₀ d₀ (hs.trans ru) dH hrf m).symm
  rw [runL_append] at whole
  have hxF : Label.finish v ∈ F := (hs.mem _).mpr (Or.inl hx)
  rw [← whole, runL_outside hfr u _ (fun z hz hwz => ?_)]
  have := soleWriters_spec hB (ru.mem_cands' z hz) hwz
  subst this
  exact ru.not_mem _ hz hxF

/-- **A result, once written, is the checked execution's.** -/
theorem value_after_writer (hw : wfB p = true) (hfr : LFramed fp eff)
    (hc : checkH p idx t = some true) (hr : racesOkE p idx fp t = true)
    {B : Nat} (hB : soleWritersB fp (cands p) B = true) {v : Nat}
    {s F : List Label} (hs : Run p [] s F) (hx : Label.finish v ∈ s) (m : Mem V) :
    runL eff s m (B, Int.ofNat v) = runL eff t m (B, Int.ofNat v) := by
  obtain ⟨G₀, r₀, d₀⟩ := checkH_true hc
  exact value_after_writerRF hw hfr r₀ d₀ (raceFree_of_racesOkE hr) hB hs hx m

/-- **D59: what a decision reads**, from a complete execution `t` on whose labels the program is
race-free. If `t` fires `finish v` (position `i`) before a label `y` reading `(B, v)` (position
`j`), then in every execution, when `y` fires, `(B, v)` holds what `t` ends with. -/
theorem decision_readsRF (hw : wfB p = true) (hfr : LFramed fp eff) {G₀ : List Label}
    (r₀ : Run p [] t G₀) (d₀ : Done p G₀) (hrf : RaceFree p fp (· ∈ t))
    {B : Nat} (hB : soleWritersB fp (cands p) B = true) {v : Nat} {y : Label}
    (hwx : lwritesB fp (.finish v) (B, Int.ofNat v) = true)
    (hry : lreadsB fp y (B, Int.ofNat v) = true)
    {i j : Nat} (hi : t[i]? = some (.finish v)) (hj : t[j]? = some y) (hij : i < j)
    {s₁ s₂ F : List Label} (hs : Run p [] (s₁ ++ y :: s₂) F) (m : Mem V) :
    runL eff s₁ m (B, Int.ofNat v) = runL eff t m (B, Int.ofNat v) := by
  have hnd := r₀.nodup
  have hil : i < t.length := (List.getElem?_eq_some_iff.mp hi).1
  have hjl : j < t.length := (List.getElem?_eq_some_iff.mp hj).1
  have hti : t[i] = .finish v := (List.getElem?_eq_some_iff.mp hi).2
  have htj : t[j] = y := (List.getElem?_eq_some_iff.mp hj).2
  have hxy : Label.finish v ≠ y := by
    intro h
    have : i = j := (List.Nodup.getElem_inj hnd).mp (by rw [hti, htj, h])
    omega
  -- The two conflict on `(B, v)`, so the program orders them.
  have hconf : LConflict fp (.finish v) y := by
    obtain ⟨a, ha, hk, hb, he⟩ := lwritesB_iff.mp hwx
    obtain ⟨b, hb', hk', hbb, he'⟩ := lreadsB_iff.mp hry
    exact ⟨a, ha, b, hb', hb.trans hbb.symm, Or.inl hk, _, he, he'⟩
  have hmx : Label.finish v ∈ t := hti ▸ List.getElem_mem hil
  have hmy : y ∈ t := htj ▸ List.getElem_mem hjl
  have hhb : HB p (.finish v) y := by
    rcases hrf _ _ hmx hmy hxy hconf with h | h
    · exact h
    · -- `y` before `finish v` in every execution, but `t` fires it after.
      exfalso
      have ht : t = t.take i ++ Label.finish v :: t.drop (i + 1) := by
        conv => lhs; rw [← List.take_append_drop i t]
        rw [List.drop_eq_getElem_cons hil, hti]
      rcases r₀.hb_prefix Inv.nil h (Ne.symm hxy) _ _ ht with h' | h'
      · simp at h'
      · obtain ⟨k, hk, hky⟩ := List.getElem_of_mem h'
        rw [List.getElem_take] at hky
        have hkl : k < t.length := by simp at hk; omega
        have : k = j := (List.Nodup.getElem_inj hnd (hi := hkl) (hj := hjl)).mp (by rw [hky, htj])
        simp at hk
        omega
  -- So `finish v` fired before `y` in this execution too.
  have hpre : Label.finish v ∈ s₁ := by
    rcases hs.hb_prefix Inv.nil hhb hxy s₁ s₂ rfl with h | h
    · simp at h
    · exact h
  obtain ⟨H, r₁, _⟩ := hs.split
  exact value_after_writerRF hw hfr r₀ d₀ hrf hB r₁ hpre m

/-- **D59: what a decision reads**, from the checks. -/
theorem decision_reads (hw : wfB p = true) (hfr : LFramed fp eff)
    (hc : checkH p idx t = some true) (hr : racesOkE p idx fp t = true)
    {B : Nat} (hB : soleWritersB fp (cands p) B = true) {v : Nat} {y : Label}
    (hwx : lwritesB fp (.finish v) (B, Int.ofNat v) = true)
    (hry : lreadsB fp y (B, Int.ofNat v) = true)
    {i j : Nat} (hi : t[i]? = some (.finish v)) (hj : t[j]? = some y) (hij : i < j)
    {s₁ s₂ F : List Label} (hs : Run p [] (s₁ ++ y :: s₂) F) (m : Mem V) :
    runL eff s₁ m (B, Int.ofNat v) = runL eff t m (B, Int.ofNat v) := by
  obtain ⟨G₀, r₀, d₀⟩ := checkH_true hc
  exact decision_readsRF hw hfr r₀ d₀ (raceFree_of_racesOkE hr) hB hwx hry hi hj hij hs m

end

end Chan

end

end Veir.Air
