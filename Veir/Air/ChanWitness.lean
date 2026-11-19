module

public import Veir.Air.ChanChunk

namespace Veir.Air

@[expose] public section

/-! # Race witnesses, proven

A race the checks find is printed with a witness: two labels `x` before `y` of a complete execution
`t` that touch a common location, one writing. That no execution order fixes it means another
complete execution fires `y` before `x`. This file proves it from a certificate:

- `reorder`: for a set of labels closed under `hbPreds` (each one's predecessors are in it), firing
  the labels of `t` in it first, then the others, each part in `t`'s order, is a complete execution;
- `certB`: a set containing `y` but not `x` (every position before `x`'s, and the positions a search
  back from `y` visits) is closed, checked on the positions between `x` and `y` only;
- `witness_sound`: the certificate checks ⇒ a complete execution fires `y` before `x`;
- `witness_soundC`: the same on chunked transfers, for the members of two chunked labels
  (`Chan.expand_run`).
-/

namespace Chan

variable {p : Prog}

/-! ### The index lists every element -/

/-- `idx` lists, for each event, every element that it puts or gets. -/
def IdxComplete (p : Prog) (idx : Array (List Nat)) : Prop :=
  ∀ k e v, p.elems[k]? = some e → (e.src = some v ∨ some v ∈ e.dsts) → v < p.graph.size →
    k ∈ idx.getD v []

theorem getD_modify {a : Array (List Nat)} {v w : Nat} {f : List Nat → List Nat} :
    (a.modify v f).getD w [] = if v = w ∧ w < a.size then f (a.getD w []) else a.getD w [] := by
  simp only [Array.getD_eq_getD_getElem?, Array.getElem?_modify]
  split <;> rename_i h
  · subst h
    by_cases hw : v < a.size
    · simp [hw, Array.getElem?_eq_getElem hw]
    · simp [hw, Array.getElem?_eq_none (Nat.le_of_not_lt hw)]
  · simp [h]

theorem foldl_modify_size (k : Nat) (vs : List Nat) (a : Array (List Nat)) :
    (vs.foldl (fun a v => a.modify v (k :: ·)) a).size = a.size := by
  induction vs generalizing a with
  | nil => rfl
  | cons v vs ih => simp only [List.foldl_cons]; rw [ih]; simp

theorem foldl_modify_keep (k : Nat) (vs : List Nat) (a : Array (List Nat)) {w j : Nat}
    (h : j ∈ a.getD w []) : j ∈ (vs.foldl (fun a v => a.modify v (k :: ·)) a).getD w [] := by
  induction vs generalizing a with
  | nil => exact h
  | cons v vs ih =>
    simp only [List.foldl_cons]
    apply ih
    rw [getD_modify]
    split
    · exact List.mem_cons_of_mem _ h
    · exact h

theorem foldl_modify_add (k : Nat) (vs : List Nat) (a : Array (List Nat)) {w : Nat}
    (hw : w ∈ vs) (hs : w < a.size) : k ∈ (vs.foldl (fun a v => a.modify v (k :: ·)) a).getD w [] := by
  induction vs generalizing a with
  | nil => simp at hw
  | cons v vs ih =>
    simp only [List.foldl_cons]
    rcases List.mem_cons.mp hw with rfl | hw
    · apply foldl_modify_keep
      rw [getD_modify]
      simp [hs]
    · exact ih _ hw (by simpa using hs)

theorem idxStep_size (a : Array (List Nat)) (k : Nat) : (idxStep p a k).size = a.size := by
  unfold idxStep; split
  · exact foldl_modify_size ..
  · rfl

theorem idxStep_keep (a : Array (List Nat)) (k : Nat) {w j : Nat} (h : j ∈ a.getD w []) :
    j ∈ (idxStep p a k).getD w [] := by
  unfold idxStep; split
  · exact foldl_modify_keep _ _ _ h
  · exact h

theorem foldl_idxStep_size (ks : List Nat) (a : Array (List Nat)) :
    (ks.foldl (idxStep p) a).size = a.size := by
  induction ks generalizing a with
  | nil => rfl
  | cons k ks ih => simp only [List.foldl_cons]; rw [ih, idxStep_size]

theorem foldl_idxStep_keep (ks : List Nat) (a : Array (List Nat)) {w j : Nat}
    (h : j ∈ a.getD w []) : j ∈ (ks.foldl (idxStep p) a).getD w [] := by
  induction ks generalizing a with
  | nil => exact h
  | cons k ks ih => exact ih _ (idxStep_keep _ _ h)

theorem foldl_idxStep_add (ks : List Nat) (a : Array (List Nat)) {k : Nat} {e : Elem} {v : Nat}
    (hk : k ∈ ks) (he : p.elems[k]? = some e) (hv : e.src = some v ∨ some v ∈ e.dsts)
    (hs : v < a.size) : k ∈ (ks.foldl (idxStep p) a).getD v [] := by
  induction ks generalizing a with
  | nil => simp at hk
  | cons k' ks ih =>
    simp only [List.foldl_cons]
    rcases List.mem_cons.mp hk with rfl | hk
    · apply foldl_idxStep_keep
      unfold idxStep
      rw [he]
      apply foldl_modify_add _ _ _ _ hs
      rw [List.mem_eraseDups]
      rcases hv with hv | hv
      · simp [hv]
      · exact List.mem_append_right _ (List.mem_filterMap.mpr ⟨some v, hv, rfl⟩)
    · exact ih _ hk (by rw [idxStep_size]; exact hs)

theorem buildIndex_complete : IdxComplete p (buildIndex p) := by
  intro k e v he hv hs
  exact foldl_idxStep_add _ _ (List.mem_range.mpr (elem_lt he)) he hv (by simpa using hs)

theorem hbPreds_sub_I {idx : Array (List Nat)} (hc : IdxComplete p idx) {l z : Label}
    (hl : ∀ v, l = .finish v → v < p.graph.size) (h : z ∈ hbPreds p l) : z ∈ hbPredsI p idx l := by
  cases l with
  | finish v =>
    have hv := hl v rfl
    simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range] at h
    simp only [hbPredsI, List.mem_cons, List.mem_flatMap]
    rcases h with h | ⟨k, _, hz⟩
    · exact Or.inl h
    · right
      refine ⟨k, ?_, hz⟩
      cases he : p.elems[k]? with
      | none => simp [he] at hz
      | some e =>
        rw [he] at hz
        simp only [List.mem_append, List.mem_filterMap, List.mem_range] at hz
        apply hc k e v he _ hv
        rcases hz with hz | ⟨i, _, hi⟩
        · left
          refine Classical.byContradiction fun hs => ?_
          simp [hs] at hz
        · right
          split at hi
          · next h => exact List.mem_of_getElem? h
          · simp at hi
  | _ => exact h

/-! ### Which labels a label waits for -/

theorem sent_of_label {G : List Label} {j : Nat} (h : sentLabel p j ∈ G) : Sent G j := by
  unfold sentLabel at h
  split at h
  · split at h
    · exact Or.inl h
    · exact Or.inr h
  · exact Or.inl h

theorem got_of_label {G : List Label} {j i : Nat} (h : gotLabel p j i ∈ G) : Got G j i := by
  unfold gotLabel at h
  split at h
  · split at h
    · exact Or.inl h
    · exact Or.inr h
  · exact Or.inl h

theorem mem_optL_of {o : Option Nat} {f : Nat → Label} {j : Nat} (h : o = some j) :
    f j ∈ optL o f := by
  subst h; simp [optL]

/-- **What enables a label is what `hbPreds` lists**: a label enabled once is enabled whenever its
predecessors have fired. -/
theorem en_of_preds {H G : List Label} {l : Label} (he : En p H l)
    (hG : ∀ z ∈ hbPreds p l, z ∈ G) : En p G l := by
  cases l with
  | start v =>
    exact ⟨he.1, fun u hu => hG _ (by simp only [hbPreds, List.mem_map]; exact ⟨u, hu, rfl⟩)⟩
  | finish v =>
    refine ⟨he.1, hG _ (by simp [hbPreds]), fun k e hk => ⟨fun hs => ?_, fun i hi => ?_⟩⟩
    · apply sent_of_label (p := p)
      apply hG
      simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range]
      exact Or.inr ⟨k, elem_lt hk, by simp [hk, hs]⟩
    · apply got_of_label (p := p)
      apply hG
      simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range]
      have hi' : i < e.dsts.length := (List.getElem?_eq_some_iff.mp hi).1
      refine Or.inr ⟨k, elem_lt hk, ?_⟩
      simp only [hk, List.mem_append, List.mem_filterMap, List.mem_range]
      exact Or.inr ⟨i, hi', by simp [hi]⟩
  | read k =>
    obtain ⟨e, hk, ⟨s, hs, _⟩, _⟩ := he
    refine ⟨e, hk, ⟨s, hs, hG _ ?_⟩, fun j hj => hG _ ?_⟩
    · simp only [hbPreds, hk, List.mem_append]; exact Or.inl (mem_optL_of hs)
    · simp only [hbPreds, hk, List.mem_append]; exact Or.inr (mem_optL_of hj)
  | push k =>
    obtain ⟨e, hk, hb, _, _⟩ := he
    refine ⟨e, hk, hb, hG _ ?_, fun j hj => sent_of_label (p := p) (hG _ ?_)⟩
    · simp [hbPreds, hk]
    · simp only [hbPreds, hk, List.mem_cons]; exact Or.inr (mem_optL_of hj)
  | pull k i =>
    obtain ⟨e, hk, hb, ⟨d, hd, _⟩, _, _⟩ := he
    refine ⟨e, hk, hb, ⟨d, hd, hG _ ?_⟩, hG _ ?_, fun j hj => got_of_label (p := p) (hG _ ?_)⟩
    · simp [hbPreds, hk, hd]
    · simp [hbPreds, hk]
    · simp only [hbPreds, hk, List.mem_cons, List.mem_append]
      exact Or.inr (mem_optL_of (f := fun j => gotLabel p j i) hj)
  | xfer k =>
    obtain ⟨e, hk, hb, _, ⟨hne, hst⟩, _⟩ := he
    refine ⟨e, hk, hb, hG _ (by simp [hbPreds, hk]), ⟨hne, fun o ho => ?_⟩, fun j hj i hi => ?_⟩
    · obtain ⟨d, rfl, _⟩ := hst o ho
      refine ⟨d, rfl, hG _ ?_⟩
      simp only [hbPreds, hk]
      exact List.mem_cons_of_mem _ (List.mem_append_left _
        (List.mem_map.mpr ⟨d, List.mem_filterMap.mpr ⟨some d, ho, rfl⟩, rfl⟩))
    · apply got_of_label (p := p)
      apply hG
      simp only [hbPreds, hk, hj]
      exact List.mem_cons_of_mem _ (List.mem_append_right _
        (List.mem_map.mpr ⟨i, List.mem_range.mpr hi, rfl⟩))

/-! ### Reordering an execution -/

/-- Labels fired in increasing `key`, each after its predecessors (fired before, or earlier in
`s`), and each enabled once somewhere: an execution. -/
theorem run_sorted (key : Label → Nat) {F s : List Label}
    (hs : s.Pairwise fun a b => key a < key b) (hen : ∀ l ∈ s, ∃ H, En p H l)
    (hn : ∀ l ∈ s, l ∉ F)
    (hpre : ∀ l ∈ s, ∀ z ∈ hbPreds p l, z ∈ F ∨ (z ∈ s ∧ key z < key l)) :
    ∃ G, Run p F s G := by
  induction s generalizing F with
  | nil => exact ⟨F, .nil F⟩
  | cons l s ih =>
    obtain ⟨hl, hs'⟩ := List.pairwise_cons.mp hs
    obtain ⟨H, hH⟩ := hen l (List.mem_cons_self ..)
    have hEn : En p F l := en_of_preds hH fun z hz => by
      rcases hpre l (List.mem_cons_self ..) z hz with h | ⟨hz', hlt⟩
      · exact h
      · rcases List.mem_cons.mp hz' with rfl | hz'
        · exact absurd hlt (Nat.lt_irrefl _)
        · exact absurd (hl z hz') (Nat.lt_asymm hlt)
    obtain ⟨G, r⟩ := ih (F := l :: F) hs' (fun m hm => hen m (List.mem_cons_of_mem _ hm))
      (fun m hm h => by
        rcases List.mem_cons.mp h with rfl | h
        · exact absurd (hl m hm) (Nat.lt_irrefl _)
        · exact hn m (List.mem_cons_of_mem _ hm) h)
      (fun m hm z hz => by
        rcases hpre m (List.mem_cons_of_mem _ hm) z hz with h | ⟨hz', hlt⟩
        · exact Or.inl (List.mem_cons_of_mem _ h)
        · rcases List.mem_cons.mp hz' with rfl | hz'
          · exact Or.inl (List.mem_cons_self ..)
          · exact Or.inr ⟨hz', hlt⟩)
    exact ⟨G, .cons hEn (hn l (List.mem_cons_self ..)) r⟩

/-- In an execution, what a label waits for fired before it. -/
theorem Run.pred_prefix {F t G : List Label} {z l : Label} (r : Run p F t G) (hi : Inv p F)
    (hz : z ∈ hbPreds p l) : ∀ t₁ t₂, t = t₁ ++ l :: t₂ → z ∈ F ∨ z ∈ t₁ := by
  induction r with
  | nil => intro t₁ t₂ h; simp at h
  | @cons F l' t G he hn rest ih =>
    intro t₁ t₂ h
    cases t₁ with
    | nil =>
      simp only [List.nil_append, List.cons.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      exact Or.inl (hb_sound hi he _ hz)
    | cons y t₁ =>
      simp only [List.cons_append, List.cons.injEq] at h
      obtain ⟨rfl, rfl⟩ := h
      rcases ih (hi.cons he) t₁ t₂ rfl with h | h
      · simp only [List.mem_cons] at h
        rcases h with rfl | h
        · exact Or.inr (List.mem_cons_self ..)
        · exact Or.inl h
      · exact Or.inr (List.mem_cons_of_mem _ h)

/-- Every label of an execution was enabled when it fired. -/
theorem Run.enabled {F t G : List Label} (r : Run p F t G) : ∀ l ∈ t, ∃ H, En p H l := by
  induction r with
  | nil => intro l h; simp at h
  | @cons F l' t G he _ _ ih =>
    intro l h
    rcases List.mem_cons.mp h with rfl | h
    · exact ⟨F, he⟩
    · exact ih l h

theorem pairwise_idxOf {t : List Label} (h : t.Nodup) :
    t.Pairwise fun a b => t.idxOf a < t.idxOf b := by
  induction t with
  | nil => exact List.Pairwise.nil
  | cons c t ih =>
    obtain ⟨hc, ht⟩ := List.nodup_cons.mp h
    have hne : ∀ b ∈ t, (c == b) = false := fun b hb => by
      simp only [beq_eq_false_iff_ne]; rintro rfl; exact hc hb
    refine List.pairwise_cons.mpr ⟨fun b hb => ?_, (ih ht).imp_of_mem fun ha hb hab => ?_⟩
    · simp [List.idxOf_cons, hne b hb]
    · simpa [List.idxOf_cons, hne _ ha, hne _ hb] using hab

/-- **Reordering**: for labels `q` closed under `hbPreds` in a complete execution `t`, firing those
of `t` in `q` first, then the others, each in `t`'s order, is a complete execution too. -/
theorem reorder {t G : List Label} (q : Label → Bool) (hr : Run p [] t G) (hd : Done p G)
    (hq : ∀ l ∈ t, q l = true → ∀ z ∈ hbPreds p l, q z = true) :
    ∃ G', Run p [] (t.filter q ++ t.filter fun l => !q l) G' ∧ Done p G' := by
  have hnd := hr.nodup
  have hpw := pairwise_idxOf hnd
  let key (l : Label) : Nat := (if q l then 0 else t.length) + t.idxOf l
  have hlen : ∀ a ∈ t, t.idxOf a < t.length := fun a ha => List.idxOf_lt_length_of_mem ha
  have hmem : ∀ l, l ∈ t.filter q ++ t.filter (fun l => !q l) ↔ l ∈ t := fun l => by
    simp only [List.mem_append, List.mem_filter]
    cases q l <;> simp
  obtain ⟨G', r'⟩ := run_sorted (p := p) (F := []) key
    (by
      refine List.pairwise_append.mpr ⟨?_, ?_, ?_⟩
      · exact (hpw.filter _).imp_of_mem fun ha hb hab => by
          simp only [List.mem_filter] at ha hb
          simp only [key, ha.2, hb.2, ite_true]; omega
      · exact (hpw.filter _).imp_of_mem fun ha hb hab => by
          simp only [List.mem_filter, Bool.not_eq_true'] at ha hb
          simp only [key, ha.2, hb.2]; simp only [Bool.false_eq_true, ite_false]; omega
      · intro a ha b hb
        simp only [List.mem_filter, Bool.not_eq_true'] at ha hb
        have := hlen a ha.1
        simp only [key, ha.2, hb.2]; simp only [ite_true, Bool.false_eq_true, ite_false]; omega)
    (fun l hl => hr.enabled l ((hmem l).mp hl))
    (fun _ _ h => by simp at h)
    (fun l hl z hz => by
      have hlt := (hmem l).mp hl
      obtain ⟨t₁, t₂, ht⟩ := List.append_of_mem hlt
      have hz1 : z ∈ t₁ := by
        rcases hr.pred_prefix Inv.nil hz t₁ t₂ ht with h | h
        · simp at h
        · exact h
      have hzt : z ∈ t := by rw [ht]; exact List.mem_append_left _ hz1
      have hidx : t.idxOf z < t.idxOf l := by
        have hpw' : (t₁ ++ l :: t₂).Pairwise fun a b => t.idxOf a < t.idxOf b := by
          rw [← ht]; exact hpw
        exact (List.pairwise_append.mp hpw').2.2 z hz1 l (List.mem_cons_self ..)
      refine Or.inr ⟨(hmem z).mpr hzt, ?_⟩
      have := hlen z hzt
      cases hql : q l with
      | true =>
        have hqz := hq l hlt hql z hz
        simp only [key, hql, hqz, ite_true]; omega
      | false =>
        cases hqz : q z <;> simp only [key, hql, hqz] <;>
          simp only [ite_true, Bool.false_eq_true, ite_false] <;> omega)
  refine ⟨G', r', fun v hv => ?_⟩
  have h1 := (Run.mem hr _).mp (hd v hv)
  simp only [List.not_mem_nil, or_false] at h1
  exact (Run.mem r' _).mpr (Or.inl ((hmem _).mpr h1))

/-- With `y` in `q` and `x` not: a complete execution fires `y` before `x`. -/
theorem reorder_before {t G : List Label} (q : Label → Bool) (hr : Run p [] t G) (hd : Done p G)
    (hq : ∀ l ∈ t, q l = true → ∀ z ∈ hbPreds p l, q z = true) {x y : Label} (hx : x ∈ t)
    (hy : y ∈ t) (hqx : q x = false) (hqy : q y = true) :
    ∃ t' G', Run p [] t' G' ∧ Done p G' ∧ ∃ t₁ t₂, t' = t₁ ++ y :: t₂ ∧ x ∈ t₂ := by
  obtain ⟨G', r', d'⟩ := reorder q hr hd hq
  have hyA : y ∈ t.filter q := List.mem_filter.mpr ⟨hy, hqy⟩
  obtain ⟨a₁, a₂, ha⟩ := List.append_of_mem hyA
  refine ⟨_, G', r', d', a₁, a₂ ++ t.filter fun l => !q l, by rw [ha]; simp, ?_⟩
  exact List.mem_append_right _ (List.mem_filter.mpr ⟨hx, by simp [hqx]⟩)

/-! ### The certificate -/

/-- Position `w` is in the set: before `i`, or marked (`mark` is indexed from `i`). -/
def posOk (i j : Nat) (mark : Array Bool) (w : Nat) : Bool := w < i || (i ≤ w && w ≤ j && mark[w - i]!)

/-- The positions before `i` and the marked ones in `[i, j]` are closed under `hbPredsI`: checked
on the marked positions only, through `ix`, which must give each position of `[i, j]` its label's.
A predecessor `ix` does not know is before `i` (it fired before, and is not in `[i, j]`). `j` is
marked and `i` not. -/
def certB (p : Prog) (idx : Array (List Nat)) (arr : Array Label) (i j : Nat) (mark : Array Bool)
    (ix : Std.HashMap Label Nat) : Bool :=
  i < j && j < arr.size && mark[j - i]! && !mark[0]! &&
  (List.range (j - i + 1)).all (fun d => ix[arr[i + d]!]? == some (i + d)) &&
  (List.range (j - i + 1)).all fun d => !mark[d]! || (hbPredsI p idx arr[i + d]!).all fun z =>
    match ix[z]? with
    | some w => arr[w]? == some z && posOk i j mark w
    | none => true

theorem getElem!_of {t : List Label} {w : Nat} {l : Label} (h : t[w]? = some l) : t[w]! = l := by
  simp [List.getElem!_eq_getElem?_getD, h]

/-- **A certified witness**: when `certB` checks on a complete execution `t`, another complete
execution fires `t[j]` before `t[i]`. -/
theorem witness_sound {idx : Array (List Nat)} {t G : List Label} {i j : Nat} {mark : Array Bool}
    {ix : Std.HashMap Label Nat} (hr : Run p [] t G) (hd : Done p G) (hc : IdxComplete p idx)
    (h : certB p idx t.toArray i j mark ix = true) :
    ∃ x y, t[i]? = some x ∧ t[j]? = some y ∧
      ∃ t' G', Run p [] t' G' ∧ Done p G' ∧ ∃ t₁ t₂, t' = t₁ ++ y :: t₂ ∧ x ∈ t₂ := by
  simp only [certB, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true, List.mem_range,
    Bool.not_eq_true', Bool.or_eq_true, List.size_toArray, List.getElem!_toArray,
    List.getElem?_toArray, beq_iff_eq] at h
  obtain ⟨⟨⟨⟨⟨hij, hjn⟩, hmj⟩, hm0⟩, hwin⟩, hcl⟩ := h
  have hnd := hr.nodup
  have hinj : ∀ {w u : Nat} {z : Label}, t[w]? = some z → t[u]? = some z → u = w := by
    intro w u z hw hu
    have hu' : u < t.length := (List.getElem?_eq_some_iff.mp hu).1
    exact ((hnd.getElem?_inj hu').mp (by rw [hu, hw])) 
  classical
  let q : Label → Bool := fun l => decide (∃ w, t[w]? = some l ∧ posOk i j mark w = true)
  have hq : ∀ l ∈ t, q l = true → ∀ z ∈ hbPreds p l, q z = true := by
    intro l hl hql z hz
    simp only [q, decide_eq_true_eq] at hql ⊢
    obtain ⟨w, hw, hpw⟩ := hql
    have hwlt : w < t.length := (List.getElem?_eq_some_iff.mp hw).1
    have hsplit : t = t.take w ++ l :: t.drop (w + 1) := by
      have h1 := List.take_append_drop w t
      rw [List.drop_eq_getElem_cons hwlt] at h1
      have h2 : t[w] = l := by simpa [List.getElem?_eq_getElem hwlt] using hw
      rw [h2] at h1
      exact h1.symm
    have hzt : z ∈ t.take w := by
      rcases hr.pred_prefix Inv.nil hz _ _ hsplit with h | h
      · simp at h
      · exact h
    obtain ⟨u, hu⟩ := List.mem_iff_getElem?.mp hzt
    rw [List.getElem?_take] at hu
    split at hu
    case isFalse => simp at hu
    rename_i huw
    simp only [posOk, Bool.or_eq_true, decide_eq_true_eq, Bool.and_eq_true] at hpw
    rcases hpw with hwi | ⟨⟨hiw, hwj⟩, hm⟩
    · exact ⟨u, hu, by simp [posOk]; omega⟩
    · have hfin : ∀ v, l = .finish v → v < p.graph.size := fun v hv => by
        obtain ⟨H, hH⟩ := hr.enabled l hl
        subst hv; exact hH.1
      have hzI := hbPreds_sub_I hc hfin hz
      have hall := hcl (w - i) (by omega)
      rw [show i + (w - i) = w by omega, getElem!_of hw] at hall
      rcases hall with hmf | hall
      · rw [hmf] at hm; exact absurd hm (by simp)
      · have hzz := hall z hzI
        split at hzz
        · next w' hw' =>
          simp only [Bool.and_eq_true, beq_iff_eq] at hzz
          exact ⟨w', hzz.1, hzz.2⟩
        · next hnone =>
          refine ⟨u, hu, ?_⟩
          simp only [posOk, Bool.or_eq_true, decide_eq_true_eq]
          refine Or.inl (Nat.lt_of_not_le fun hui => ?_)
          have := hwin (u - i) (by omega)
          rw [show i + (u - i) = u by omega, getElem!_of hu] at this
          rw [this] at hnone
          exact absurd hnone (by simp)
  have hilt : i < t.length := by omega
  obtain ⟨x, hx⟩ : ∃ x, t[i]? = some x := ⟨_, List.getElem?_eq_getElem hilt⟩
  obtain ⟨y, hy⟩ : ∃ y, t[j]? = some y := ⟨_, List.getElem?_eq_getElem hjn⟩
  have hqx : q x = false := by
    simp only [q, decide_eq_false_iff_not, not_exists, not_and]
    intro w hw hpw
    have := hinj hx hw
    subst this
    simp [posOk, hm0] at hpw
  have hqy : q y = true := by
    simp only [q, decide_eq_true_eq]
    exact ⟨j, hy, by simp [posOk, hmj]; omega⟩
  exact ⟨x, y, hx, hy, reorder_before q hr hd hq (List.mem_of_getElem? hx)
    (List.mem_of_getElem? hy) hqx hqy⟩

/-! ### On chunked transfers -/

/-- **A certified witness on chunks**: when `certB` checks on the chunked program's complete
execution `tc`, for members `x` of `tc[i]` and `y` of `tc[j]`, a complete execution of the element
program fires `y` before `x` (and `tc`, expanded, fires `x` before `y`). -/
theorem witness_soundC {ch : Chunking} {tc Gc : List Label} {i j : Nat} {mark : Array Bool}
    {ix : Std.HashMap Label Nat} (hv : validB p ch = true)
    (hr : Run (chunked p ch) [] tc Gc) (hd : Done (chunked p ch) Gc)
    (h : certB (chunked p ch) (buildIndex (chunked p ch)) tc.toArray i j mark ix = true) :
    ∃ X Y, tc[i]? = some X ∧ tc[j]? = some Y ∧ ∀ x ∈ expandL ch X, ∀ y ∈ expandL ch Y,
      ∃ t' G', Run p [] t' G' ∧ Done p G' ∧ ∃ t₁ t₂, t' = t₁ ++ y :: t₂ ∧ x ∈ t₂ := by
  obtain ⟨X, Y, hX, hY, tc', Gc', r', d', c₁, c₂, rfl, hXc⟩ :=
    witness_sound hr hd buildIndex_complete h
  refine ⟨X, Y, hX, hY, fun x hx y hy => ?_⟩
  obtain ⟨G', r'', d''⟩ := expand_run (valid_of_validB hv) r' d'
  obtain ⟨a, b, hab⟩ := List.append_of_mem hy
  refine ⟨_, G', r'', d'', c₁.flatMap (expandL ch) ++ a, b ++ c₂.flatMap (expandL ch), ?_, ?_⟩
  · simp [List.flatMap_append, hab]
  · exact List.mem_append_right _ (List.mem_flatMap.mpr ⟨X, hXc, hx⟩)

/-- **A certified witness inside chunks**: `certB` on the element program and the chunked
execution `tc`, expanded (a complete execution, `Chan.expand_run`). -/
theorem witness_soundE {ch : Chunking} {tc Gc : List Label} {i j : Nat} {mark : Array Bool}
    {ix : Std.HashMap Label Nat} (hv : validB p ch = true)
    (hr : Run (chunked p ch) [] tc Gc) (hd : Done (chunked p ch) Gc)
    (h : certB p (buildIndex p) (tc.flatMap (expandL ch)).toArray i j mark ix = true) :
    ∃ x y, (tc.flatMap (expandL ch))[i]? = some x ∧ (tc.flatMap (expandL ch))[j]? = some y ∧
      ∃ t' G', Run p [] t' G' ∧ Done p G' ∧ ∃ t₁ t₂, t' = t₁ ++ y :: t₂ ∧ x ∈ t₂ := by
  obtain ⟨G, r, d⟩ := expand_run (valid_of_validB hv) hr hd
  exact witness_sound r d buildIndex_complete h

/-! ### Finding the certificate -/

/-- A certificate for positions `i < j` of `arr`: search back from `j` through `hbPredsI` over the
positions in `[i, j]`, marking those reached. `false` when `i` is reached (the pair is ordered),
when `fuel` runs out, or when the certificate does not check. -/
def certify (p : Prog) (idx : Array (List Nat)) (arr : Array Label) (i j : Nat) (fuel : Nat) :
    Bool := Id.run do
  if !(i < j && j < arr.size) then return false
  let ix : Std.HashMap Label Nat := (List.range (j - i + 1)).foldl
    (fun m d => m.insert arr[i + d]! (i + d)) {}
  let mut mark : Array Bool := Array.replicate (j - i + 1) false
  mark := mark.set! (j - i) true
  let mut todo : List Label := hbPredsI p idx arr[j]!
  let mut done := false
  for _ in [0:fuel] do
    match todo with
    | [] => done := true; break
    | l :: rest =>
      todo := rest
      match ix[l]? with
      | some w =>
        if w == i then return false
        if mark[w - i]! then continue
        mark := mark.set! (w - i) true
        todo := hbPredsI p idx l ++ todo
      | none => continue
  return done && certB p idx arr i j mark ix

end Chan

end

end Veir.Air
