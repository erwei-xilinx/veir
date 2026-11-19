module

public import Veir.Air.ChanWitness
public import Veir.Air.ChanDecide

namespace Veir.Air

@[expose] public section

/-! # Footprints as ranges

A footprint that lists every position it touches costs memory and time proportional to the
positions: a transfer of a 512x4096 buffer lists two million. Here an access is a list of ranges
`[lo, hi)` (`RAcc`); its positions (`RAcc.elems`) are what the theorems speak of
(`toLFp`), never computed by the check.

The race check (`racesOkRange`) cuts each buffer at the ends of every range its accesses have
(`ends`): between two consecutive ends, every position is touched by the same accesses. It then
checks each piece (`segment`) as `racesOkR` checks a position, and is sound for the positions
(`raceFree_of_racesOkRange`): the accesses of a position are those of its piece.
-/

namespace Chan

/-- Footprints of labels, as ranges. -/
abbrev RFp := Label → List RAcc

/-- What the footprints mean: the positions of their ranges. -/
def toLFp (rfp : RFp) : LFp := fun x => (rfp x).map RAcc.toAccess

theorem mem_elems {a : RAcc} {q : Int} (h : q ∈ a.elems) : ∃ r ∈ a.ranges, r.1 ≤ q ∧ q < r.2 := by
  simp only [RAcc.elems, List.mem_flatMap, List.mem_map, List.mem_range] at h
  obtain ⟨⟨lo, hi⟩, hr, k, hk, rfl⟩ := h
  have := Int.lt_toNat.mp hk
  simp only at this
  exact ⟨(lo, hi), hr, by simp; omega, by simp; omega⟩

/-! ### Where each buffer is cut -/

/-- Strictly increasing. -/
def sortedB (E : Array Int) : Bool := (List.range (E.size - 1)).all fun k => E[k]! < E[k + 1]!

theorem sorted_mono {E : Array Int} (h : sortedB E = true) {i j : Nat} (hij : i < j) (hj : j < E.size) :
    E[i]! < E[j]! := by
  simp only [sortedB, List.all_eq_true, List.mem_range, decide_eq_true_eq] at h
  induction j with
  | zero => omega
  | succ j ih =>
    rcases Nat.lt_or_eq_of_le (Nat.le_of_lt_succ hij) with h' | h'
    · exact Int.lt_trans (ih h' (by omega)) (h j (by omega))
    · subst h'; exact h i (by omega)

/-- The first position of `E` whose value is at least `x` (binary search; `E` sorted). -/
def lowerBound (E : Array Int) (x : Int) : Nat := Id.run do
  let mut lo := 0
  let mut hi := E.size
  for _ in [0:64] do
    if lo < hi then
      let mid := (lo + hi) / 2
      if E[mid]! < x then lo := mid + 1 else hi := mid
  return lo

/-- The ends in `[lo, hi)`: the starts of the pieces the range covers. Found by binary search, and
checked; when the check fails, by looking at every end. -/
def segStarts (E : Array Int) (lo hi : Int) : List Int :=
  let i := lowerBound E lo
  let j := lowerBound E hi
  if i ≤ j && j ≤ E.size && (i == 0 || E[i - 1]! < lo) && (j == E.size || hi ≤ E[j]!) then
    ((E.extract i j).toList.filter fun e => lo ≤ e && e < hi)
  else E.toList.filter fun e => lo ≤ e && e < hi

theorem mem_segStarts {E : Array Int} (hs : sortedB E = true) {lo hi e : Int} (he : e ∈ E.toList)
    (hlo : lo ≤ e) (hhi : e < hi) : e ∈ segStarts E lo hi := by
  simp only [segStarts]
  split
  · rename_i hc
    simp only [Bool.and_eq_true, decide_eq_true_eq, Bool.or_eq_true, beq_iff_eq] at hc
    obtain ⟨⟨⟨hij, hjs⟩, hlb⟩, hj⟩ := hc
    simp only [List.mem_filter, Bool.and_eq_true, decide_eq_true_eq]
    refine ⟨?_, hlo, hhi⟩
    obtain ⟨k, hk, rfl⟩ := List.mem_iff_getElem.mp he
    simp only [Array.length_toList] at hk
    have hek : E.toList[k] = E[k]! := by simp [hk]
    rw [hek] at hlo hhi ⊢
    -- `k` lies between the two bounds.
    have hk1 : lowerBound E lo ≤ k := by
      rcases hlb with h0 | hlt
      · omega
      · rcases Nat.lt_or_ge k (lowerBound E lo) with hcon | hge
        · rcases Nat.lt_or_eq_of_le (show k ≤ lowerBound E lo - 1 by omega) with h' | h'
          · have := sorted_mono hs h' (by omega); omega
          · rw [h'] at hlo; omega
        · exact hge
    have hk2 : k < lowerBound E hi := by
      rcases hj with h0 | hle
      · omega
      · rcases Nat.lt_or_ge k (lowerBound E hi) with hlt | hcon
        · exact hlt
        · rcases Nat.lt_or_eq_of_le hcon with h' | h'
          · have := sorted_mono hs h' hk; omega
          · rw [h'] at hle; omega
    simp only [Array.toList_extract, List.mem_iff_getElem]
    refine ⟨k - lowerBound E lo, by simp; omega, ?_⟩
    simp [show lowerBound E lo + (k - lowerBound E lo) = k by omega, hk]
  · simp only [List.mem_filter, Bool.and_eq_true, decide_eq_true_eq]
    exact ⟨he, hlo, hhi⟩

/-! ### The check -/

/-- Sorted, without adjacent repeats. -/
def dedupSortedI : List Int → List Int
  | a :: b :: t => if a = b then dedupSortedI (b :: t) else a :: dedupSortedI (b :: t)
  | l => l

/-- Each buffer's ends: the bounds of the ranges of the labels of `t`, sorted. -/
def ends (rfp : RFp) (t : List Label) : Std.HashMap Nat (Array Int) :=
  let m : Std.HashMap Nat (Array Int) := t.foldl (fun m x =>
    (rfp x).foldl (fun m a =>
      let arr := m.getD a.buf #[]
      let m := m.erase a.buf
      m.insert a.buf (a.ranges.foldl (fun arr r => (arr.push r.1).push r.2) arr)) m) {}
  m.map fun _ arr => (dedupSortedI (arr.toList.mergeSort (· ≤ ·))).toArray

/-- Every access of every label of `t`, at the start of each piece of its buffer it covers. -/
def emittedR (E : Nat → Array Int) (rfp : RFp) (t : List Label) : List Entry :=
  t.zipIdx.flatMap fun (x, i) => (rfp x).flatMap fun a => a.ranges.flatMap fun (lo, hi) =>
    (segStarts (E a.buf) lo hi).map fun s => ((a.buf, s), i, a.kind == .write)

/-- `lo` is one of the ends `E`. -/
def isEnd (E : Array Int) (lo : Int) : Bool :=
  let i := lowerBound E lo
  decide (i < E.size) && E[i]! == lo

/-- **The race check on ranges**: the ends are sorted and include every range's start, and each
piece's accesses are ordered (`scanOk`). -/
def racesOkRange (reach : Nat → Nat → Bool) (rfp : RFp) (t : List Label) : Bool :=
  let em := ends rfp t
  let E (b : Nat) := em.getD b #[]
  em.toList.all (fun (_, arr) => sortedB arr) &&
  t.all (fun x => (rfp x).all fun a => a.ranges.all fun r => isEnd (E a.buf) r.1) &&
  (groups (emittedR E rfp t)).toList.all fun (_, arr) => scanOk reach 0 none [] arr.toList

theorem mem_emittedR {E : Nat → Array Int} {rfp : RFp} {t : List Label} {x : Label} {i : Nat}
    (hx : t[i]? = some x) {a : RAcc} (ha : a ∈ rfp x) {r : Int × Int} (hr : r ∈ a.ranges) {s : Int}
    (hs : s ∈ segStarts (E a.buf) r.1 r.2) : ((a.buf, s), i, a.kind == .write) ∈ emittedR E rfp t := by
  simp only [emittedR, List.mem_flatMap, List.mem_map]
  refine ⟨(x, i), List.mem_zipIdx_iff_getElem?.mpr hx, a, ha, r, hr, s, hs, rfl⟩

/-- The piece of `E` position `q` is in: the last end at or before it. -/
theorem piece {E : Array Int} {lo q : Int} (hlo : lo ∈ E.toList) (hq : lo ≤ q) :
    ∃ s, s ∈ E.toList ∧ s ≤ q ∧ lo ≤ s ∧ ∀ e ∈ E.toList, e ≤ q → e ≤ s := by
  cases hm : (E.toList.filter (· ≤ q)).max? with
  | none =>
    have := List.max?_eq_none_iff.mp hm
    have hin : lo ∈ E.toList.filter (· ≤ q) := List.mem_filter.mpr ⟨hlo, by simpa using hq⟩
    rw [this] at hin
    cases hin
  | some s =>
    obtain ⟨hs, hmax⟩ := List.max?_eq_some_iff.mp hm
    obtain ⟨hsE, hsq⟩ := List.mem_filter.mp hs
    refine ⟨s, hsE, by simpa using hsq, hmax lo (List.mem_filter.mpr ⟨hlo, by simpa using hq⟩),
      fun e he heq => hmax e (List.mem_filter.mpr ⟨he, by simpa using heq⟩)⟩

theorem group_mem' {es : List Entry} {e : Entry} (he : e ∈ es) :
    e.2 ∈ ((groups es).getD e.1 #[]).toList := by
  rw [groups, groups_spec]
  simp only [Std.HashMap.getD_empty, Array.toList_empty, List.nil_append, List.mem_map,
    List.mem_filter, beq_iff_eq]
  exact ⟨e, ⟨he, rfl⟩, rfl⟩

theorem isEnd_mem {E : Array Int} {lo : Int} (h : isEnd E lo = true) : lo ∈ E.toList := by
  simp only [isEnd, Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] at h
  obtain ⟨hi, he⟩ := h
  rw [← he]
  simp [hi]

/-- **The range check is sound**, for the positions of the ranges, for any `reach` that only
claims orders `HB` has. -/
theorem raceFree_of_racesOkRange {reach : Nat → Nat → Bool} {rfp : RFp} {t : List Label}
    (hs : ∀ i j, reach i j = true → PosHB p t i j) (h : racesOkRange reach rfp t = true) :
    RaceFree p (toLFp rfp) (· ∈ t) := by
  simp only [racesOkRange, Bool.and_eq_true, List.all_eq_true] at h
  obtain ⟨⟨hsorted, hends⟩, hscanAll⟩ := h
  let em := ends rfp t
  let E (b : Nat) := em.getD b #[]
  have hsortE (b : Nat) : sortedB (E b) = true := by
    simp only [E, Std.HashMap.getD_eq_getD_getElem?]
    cases hb : em[b]? with
    | none => simp [sortedB]
    | some arr => exact hsorted (b, arr) (Std.HashMap.mem_toList_iff_getElem?_eq_some.mpr hb)
  intro x y hx hy hne hc
  obtain ⟨A, hA, B, hB, hbuf, hw, q, hqa, hqb⟩ := hc
  simp only [toLFp, List.mem_map] at hA hB
  obtain ⟨a, ha, rfl⟩ := hA
  obtain ⟨b, hb, rfl⟩ := hB
  simp only [RAcc.toAccess] at hbuf hw hqa hqb
  obtain ⟨ra, hra, hla, hha⟩ := mem_elems hqa
  obtain ⟨rb, hrb, hlb, hhb⟩ := mem_elems hqb
  have gx : t[t.idxOf x]? = some x := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hx), List.getElem_idxOf]
  have gy : t[t.idxOf y]? = some y := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hy), List.getElem_idxOf]
  have hij : t.idxOf x ≠ t.idxOf y := fun e => hne (by rw [e] at gx; rw [gx] at gy; cases gy; rfl)
  -- The piece of position `q` in buffer `a.buf`.
  have hla_end := isEnd_mem (hends x hx a ha ra hra)
  have hlb_end := isEnd_mem (hends y hy b hb rb hrb)
  rw [← hbuf] at hlb_end
  obtain ⟨s, hsE, hsq, hlos, hmax⟩ := piece hla_end hla
  have hlbs : rb.1 ≤ s := hmax rb.1 hlb_end hlb
  have sa : s ∈ segStarts (E a.buf) ra.1 ra.2 := mem_segStarts (hsortE _) hsE hlos (by omega)
  have sb : s ∈ segStarts (E b.buf) rb.1 rb.2 := by
    rw [← hbuf]; exact mem_segStarts (hsortE _) hsE hlbs (by omega)
  have ex := group_mem' (mem_emittedR gx ha hra sa)
  have ey := group_mem' (mem_emittedR gy hb hrb sb)
  simp only at ex ey
  rw [← hbuf] at ey
  let l : Loc := (a.buf, s)
  have hscan : scanOk reach 0 none [] ((groups (emittedR E rfp t)).getD l #[]).toList = true := by
    rw [Std.HashMap.getD_eq_getD_getElem?]
    cases hl : (groups (emittedR E rfp t))[l]? with
    | none => simp [scanOk]
    | some arr => exact hscanAll (l, arr) (Std.HashMap.mem_toList_iff_getElem?_eq_some.mpr hl)
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

/-- The range check with orders from the event graph, as `racesOkE`. -/
def racesOkRangeE (p : Prog) (idx : Array (List Nat)) (rfp : RFp) (t : List Label) : Bool :=
  let g := evGraph p idx
  racesOkRange (labelReach p idx localDepth g g.reachRows t.toArray) rfp t

theorem raceFree_of_racesOkRangeE {idx : Array (List Nat)} {rfp : RFp} {t : List Label}
    (h : racesOkRangeE p idx rfp t = true) : RaceFree p (toLFp rfp) (· ∈ t) :=
  raceFree_of_racesOkRange (fun _ _ hr => labelReach_sound rfl rfl hr) h

/-- **Outcomes, with footprints as ranges**: `outcome_uniqueE` with `racesOkRangeE`. -/
theorem outcome_uniqueR {V : Type} {rfp : RFp} {eff : Label → Mem V → Mem V} {idx : Array (List Nat)}
    {t : List Label} (hw : wfB p = true) (hfr : LFramed (toLFp rfp) eff)
    (hc : checkH p idx t = some true) (hr : racesOkRangeE p idx rfp t = true)
    {t' G : List Label} (h : Run p [] t' G) (d : Done p G) (m : Mem V) :
    runL eff t' m = runL eff t m := by
  obtain ⟨G₀, r, d₀⟩ := checkH_true hc
  exact (deterministic (wf_of_wfB hw) hfr r d₀ h d (raceFree_of_racesOkRangeE hr) m).symm

/-! ### Chunks, as ranges -/

/-- One step of `joinRanges`: a range that starts within the last one extends it. -/
def joinStep (acc : List (Int × Int)) (r : Int × Int) : List (Int × Int) :=
  match acc with
  | (lo, hi) :: rest => if lo ≤ r.1 ∧ r.1 ≤ hi then (lo, max hi r.2) :: rest else r :: acc
  | [] => [r]

/-- Ranges sorted by start, those that meet or overlap joined. -/
def joinRanges (rs : List (Int × Int)) : List (Int × Int) :=
  ((rs.mergeSort fun a b => a.1 ≤ b.1).foldl joinStep []).reverse

def Cov (rs : List (Int × Int)) (q : Int) : Prop := ∃ r ∈ rs, r.1 ≤ q ∧ q < r.2

theorem joinStep_keep {acc : List (Int × Int)} {r : Int × Int} {q : Int} (h : Cov acc q) :
    Cov (joinStep acc r) q := by
  obtain ⟨r', hr', h1, h2⟩ := h
  match acc, hr' with
  | (lo, hi) :: rest, hr' =>
    simp only [joinStep]
    split
    · rename_i hc
      rcases List.mem_cons.mp hr' with rfl | hr'
      · exact ⟨(lo, max hi r.2), List.mem_cons_self .., h1, by simp at h2 ⊢; omega⟩
      · exact ⟨r', List.mem_cons_of_mem _ hr', h1, h2⟩
    · exact ⟨r', List.mem_cons_of_mem _ hr', h1, h2⟩

theorem joinStep_add {acc : List (Int × Int)} {r : Int × Int} {q : Int} (h1 : r.1 ≤ q) (h2 : q < r.2) :
    Cov (joinStep acc r) q := by
  match acc with
  | (lo, hi) :: rest =>
    simp only [joinStep]
    split
    · rename_i hc
      exact ⟨(lo, max hi r.2), List.mem_cons_self .., by simp; omega, by simp; omega⟩
    · exact ⟨r, List.mem_cons_self .., h1, h2⟩
  | [] => exact ⟨r, List.mem_singleton_self _, h1, h2⟩

theorem foldl_join_cov : ∀ (rs acc : List (Int × Int)) (q : Int), Cov acc q ∨ Cov rs q →
    Cov (rs.foldl joinStep acc) q
  | [], acc, q, h => by
    rcases h with h | ⟨r, hr, _⟩
    · exact h
    · simp at hr
  | r :: rs, acc, q, h => by
    simp only [List.foldl_cons]
    apply foldl_join_cov rs
    rcases h with h | ⟨r', hr', h1, h2⟩
    · exact Or.inl (joinStep_keep h)
    · rcases List.mem_cons.mp hr' with rfl | hr'
      · exact Or.inl (joinStep_add h1 h2)
      · exact Or.inr ⟨r', hr', h1, h2⟩

theorem joinRanges_cov {rs : List (Int × Int)} {q : Int} (h : Cov rs q) : Cov (joinRanges rs) q := by
  obtain ⟨r, hr, h1, h2⟩ := h
  obtain ⟨r', hr', h1', h2'⟩ := foldl_join_cov (rs.mergeSort fun a b => a.1 ≤ b.1) [] q
    (Or.inr ⟨r, List.mem_mergeSort.mpr hr, h1, h2⟩)
  exact ⟨r', List.mem_reverse.mpr hr', h1', h2'⟩

/-- A chunked label's footprint, as ranges: its members', per buffer and kind, ranges that meet
joined. -/
def chunkRFp (ch : Chunking) (rfp : RFp) : RFp := fun X =>
  let accs := (List.range (width ch X)).flatMap fun a => rfp (memL ch X a)
  let keys := dedupBK (accs.map fun a => (a.buf, a.kind == .write))
  keys.map fun (b, w) =>
    { buf := b, kind := if w then .write else .read,
      ranges := joinRanges ((accs.filter fun a => a.buf == b && (a.kind == .write) == w).flatMap (·.ranges)) }

theorem elems_cov {a : RAcc} {q : Int} : q ∈ a.elems ↔ Cov a.ranges q := by
  constructor
  · intro h; obtain ⟨r, hr, h1, h2⟩ := mem_elems h; exact ⟨r, hr, h1, h2⟩
  · rintro ⟨⟨lo, hi⟩, hr, h1, h2⟩
    simp only [RAcc.elems, List.mem_flatMap, List.mem_map, List.mem_range]
    refine ⟨(lo, hi), hr, (q - lo).toNat, ?_, ?_⟩ <;> simp at h1 h2 ⊢ <;> omega

/-- **Each member's access is covered by its chunked label's.** -/
theorem chunkRFp_cov (hv : Valid p ch) (rfp : RFp) {x : Label} (hx : Kinded p x) :
    ∀ a ∈ toLFp rfp x, ∃ b ∈ toLFp (chunkRFp ch rfp) (up ch x), Covers a b := by
  intro a ha
  simp only [toLFp, List.mem_map] at ha
  obtain ⟨a, ha, rfl⟩ := ha
  have hm : MemOf p ch x (up ch x) := ⟨hx, rfl⟩
  have hacc : a ∈ (List.range (width ch (up ch x))).flatMap fun k => rfp (memL ch (up ch x) k) := by
    simp only [List.mem_flatMap, List.mem_range]
    exact ⟨eidx ch x, eidx_lt hv hm, by rw [← member_eq hv hm]; exact ha⟩
  let key := (a.buf, a.kind == .write)
  let accs := (List.range (width ch (up ch x))).flatMap fun k => rfp (memL ch (up ch x) k)
  let rs := (accs.filter fun b => b.buf == a.buf && (b.kind == .write) == (a.kind == .write)).flatMap (·.ranges)
  let b : RAcc := { buf := a.buf, kind := if a.kind == .write then .write else .read, ranges := joinRanges rs }
  refine ⟨b.toAccess, ?_, ?_⟩
  · simp only [toLFp, chunkRFp, List.mem_map]
    exact ⟨_, ⟨key, mem_dedupBK (List.mem_map.mpr ⟨a, hacc, rfl⟩), rfl⟩, rfl⟩
  · refine ⟨rfl, fun hw => by simp only [RAcc.toAccess] at hw; simp [b, hw, RAcc.toAccess], fun q hq => ?_⟩
    simp only [RAcc.toAccess] at hq ⊢
    rw [elems_cov] at hq ⊢
    apply joinRanges_cov
    obtain ⟨r, hr, h1, h2⟩ := hq
    refine ⟨r, List.mem_flatMap.mpr ⟨a, List.mem_filter.mpr ⟨hacc, by simp⟩, hr⟩, h1, h2⟩

/-- `slotOwnB` on ranges: members touch the slot only at their own element. -/
def slotOwnBR (ch : Chunking) (rfp : RFp) (slot : Nat) (X : Label) : Bool :=
  (List.range (width ch X)).all fun a => (rfp (memL ch X a)).all fun acc =>
    acc.buf != slot || acc.ranges.all fun r => r.1 == elemPos (memL ch X a) && r.2 == r.1 + 1

def bufKindsR (ch : Chunking) (rfp : RFp) (slot : Nat) (X : Label) : List (Nat × Bool) :=
  dedupBK ((List.range (width ch X)).flatMap fun a => (rfp (memL ch X a)).filterMap fun acc =>
    if acc.buf = slot then none else some (acc.buf, acc.kind == .write))

/-- `condB` on ranges. -/
def condBR (ch : Chunking) (rfp : RFp) (slot : Nat) (tc : List Label) : Bool :=
  tc.all fun T => (sources T).all fun X =>
    decide (width ch T ≤ 1) || slotOwnBR ch rfp slot X && slotOwnBR ch rfp slot T &&
    let bt := bufKindsR ch rfp slot T
    (bufKindsR ch rfp slot X).all fun (b, w) => bt.all fun (b', w') => b != b' || (!w && !w')

theorem bufKindsR_eq (rfp : RFp) (slot : Nat) (X : Label) :
    bufKindsR ch rfp slot X = bufKinds ch (toLFp rfp) slot X := by
  simp only [bufKindsR, bufKinds, toLFp, List.filterMap_map]
  rfl

theorem slotOwn_of_R {rfp : RFp} {slot : Nat} {X : Label} (h : slotOwnBR ch rfp slot X = true) :
    slotOwnB ch (toLFp rfp) slot X = true := by
  simp only [slotOwnBR, slotOwnB, toLFp, List.all_eq_true, List.mem_range, List.mem_map,
    Bool.or_eq_true, bne_iff_ne, ne_eq, Bool.and_eq_true, beq_iff_eq, forall_exists_index,
    and_imp] at h ⊢
  intro a ha acc' acc hacc hacc'
  subst hacc'
  rcases h a ha acc hacc with h | h
  · exact Or.inl h
  · right
    intro e he
    obtain ⟨r, hr, h1, h2⟩ := mem_elems he
    obtain ⟨hr1, hr2⟩ := h r hr
    simp only [RAcc.toAccess] at *
    omega

theorem condB_of_condBR {rfp : RFp} {slot : Nat} {tc : List Label} (h : condBR ch rfp slot tc = true) :
    condB ch (toLFp rfp) slot tc = true := by
  simp only [condBR, condB, pairCondB, List.all_eq_true, Bool.or_eq_true, Bool.and_eq_true] at h ⊢
  intro T hT X hX
  rcases h T hT X hX with h | ⟨⟨h1, h2⟩, h3⟩
  · exact Or.inl h
  · right
    refine ⟨⟨slotOwn_of_R h1, slotOwn_of_R h2⟩, ?_⟩
    rw [← bufKindsR_eq, ← bufKindsR_eq]
    exact h3

/-- **The chunked verdicts, with footprints as ranges.** -/
theorem chunked_soundR {rfp : RFp} {slot : Nat} {idx : Array (List Nat)} {tc : List Label}
    (hv : validB p ch = true) (hcond : condBR ch rfp slot tc = true)
    (hc : checkH (chunked p ch) idx tc = some true)
    (hr : racesOkRangeE (chunked p ch) idx (chunkRFp ch rfp) tc = true) :
    (∃ t G, Run p [] t G ∧ Done p G) ∧
      RaceFree p (toLFp rfp) fun x => Kinded p x ∧ up ch x ∈ tc := by
  have hv' := valid_of_validB hv
  obtain ⟨G, r, d⟩ := checkH_true hc
  refine ⟨completes_of_chunked hv' r d, ?_⟩
  exact raceFree_of_chunked hv' (condOk_of_condB hv' (condB_of_condBR hcond))
    (fun x hx => chunkRFp_cov hv' rfp hx) (fun x h => ⟨h.1, h.2⟩) (raceFree_of_racesOkRangeE hr)

/-- **Outcomes, on chunks, with footprints as ranges.** -/
theorem outcome_uniqueCR {V : Type} {rfp : RFp} {eff : Label → Mem V → Mem V} {slot : Nat}
    {idx : Array (List Nat)} {tc : List Label} (hw : wfB p = true) (hfr : LFramed (toLFp rfp) eff)
    (hv : validB p ch = true) (hcond : condBR ch rfp slot tc = true)
    (hc : checkH (chunked p ch) idx tc = some true)
    (hr : racesOkRangeE (chunked p ch) idx (chunkRFp ch rfp) tc = true)
    {t' G' : List Label} (h : Run p [] t' G') (d : Done p G') (m : Mem V) :
    runL eff t' m = runL eff (tc.flatMap (expandL ch)) m := by
  have hv' := valid_of_validB hv
  obtain ⟨Gc, rc, dc⟩ := checkH_true hc
  obtain ⟨G, r, dG⟩ := expand_run hv' rc dc
  have hrf := (chunked_soundR hv hcond hc hr).2
  have hS : RaceFree p (toLFp rfp) (· ∈ tc.flatMap (expandL ch)) := by
    intro x y hx hy hne hcf
    have mem (z : Label) (hz : z ∈ tc.flatMap (expandL ch)) : Kinded p z ∧ up ch z ∈ tc := by
      simp only [List.mem_flatMap, expandL, List.mem_map, List.mem_range] at hz
      obtain ⟨X, hX, a, ha, rfl⟩ := hz
      have hk := kinded_of_en (rc.inv Inv.nil X ((rc.mem X).mpr (Or.inl hX)))
      have hm := memL_mem hv' hk ha
      exact ⟨hm.1, by rw [hm.2]; exact hX⟩
    exact hrf x y (mem x hx) (mem y hy) hne hcf
  exact (deterministic (wf_of_wfB hw) hfr r dG h d hS m).symm

/-! ### What decisions read, on ranges -/

def inRanges (rs : List (Int × Int)) (q : Int) : Bool := rs.any fun r => r.1 ≤ q && q < r.2

theorem inRanges_elems {a : RAcc} {q : Int} (h : inRanges a.ranges q = true) : q ∈ a.elems := by
  rw [elems_cov]
  simp only [inRanges, List.any_eq_true, Bool.and_eq_true, decide_eq_true_eq] at h
  obtain ⟨r, hr, h1, h2⟩ := h
  exact ⟨r, hr, h1, h2⟩

def lwritesBR (rfp : RFp) (l : Label) (x : Loc) : Bool :=
  (rfp l).any fun a => a.kind == .write && a.buf == x.1 && inRanges a.ranges x.2

def lreadsBR (rfp : RFp) (l : Label) (x : Loc) : Bool :=
  (rfp l).any fun a => a.kind == .read && a.buf == x.1 && inRanges a.ranges x.2

theorem lwritesB_of_R {rfp : RFp} {l : Label} {x : Loc} (h : lwritesBR rfp l x = true) :
    lwritesB (toLFp rfp) l x = true := by
  simp only [lwritesBR, List.any_eq_true, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨a, ha, ⟨hk, hb⟩, hq⟩ := h
  simp only [lwritesB, toLFp, List.any_map, List.any_eq_true, Function.comp, RAcc.toAccess,
    Bool.and_eq_true, beq_iff_eq, List.contains_iff_mem]
  exact ⟨a, ha, ⟨hk, hb⟩, inRanges_elems hq⟩

theorem lreadsB_of_R {rfp : RFp} {l : Label} {x : Loc} (h : lreadsBR rfp l x = true) :
    lreadsB (toLFp rfp) l x = true := by
  simp only [lreadsBR, List.any_eq_true, Bool.and_eq_true, beq_iff_eq] at h
  obtain ⟨a, ha, ⟨hk, hb⟩, hq⟩ := h
  simp only [lreadsB, toLFp, List.any_map, List.any_eq_true, Function.comp, RAcc.toAccess,
    Bool.and_eq_true, beq_iff_eq, List.contains_iff_mem]
  exact ⟨a, ha, ⟨hk, hb⟩, inRanges_elems hq⟩

/-- `soleWritersB` on ranges: each write to `B` is a `finish v` writing only `[v, v + 1)`. -/
def soleWritersBR (rfp : RFp) (cs : List Label) (B : Nat) : Bool :=
  cs.all fun z => (rfp z).all fun a =>
    !(a.kind == .write && a.buf == B) ||
      match z with
      | .finish v => a.ranges.all fun r => r.1 == Int.ofNat v && r.2 == Int.ofNat v + 1
      | _ => false

theorem soleWritersB_of_R {rfp : RFp} {cs : List Label} {B : Nat} (h : soleWritersBR rfp cs B = true) :
    soleWritersB (toLFp rfp) cs B = true := by
  simp only [soleWritersBR, List.all_eq_true] at h
  simp only [soleWritersB, toLFp, List.all_eq_true, List.mem_map]
  intro z hz a' ⟨a, ha, he⟩
  subst he
  have := h z hz a ha
  simp only [RAcc.toAccess] at this ⊢
  revert this
  cases z with
  | finish v =>
    simp only [Bool.or_eq_true, Bool.not_eq_true', List.all_eq_true, Bool.and_eq_true, beq_iff_eq]
    rintro (h | h)
    · exact Or.inl h
    · right
      intro e he
      obtain ⟨r, hr, h1, h2⟩ := mem_elems he
      obtain ⟨hr1, hr2⟩ := h r hr
      omega
  | _ => simp

/-- How many labels `Chan.certify` visits for one pair. -/
def windowFuel : Nat := 200000

/-- `raceWitnessesD` on ranges: one witness per pair of owners and buffer, piece by piece, each
with a certificate (`Chan.certify`): `Chan.witness_sound` proves another complete execution fires
the pair the other way round. -/
def raceWitnessesR (p : Prog) (idx : Array (List Nat)) (rfp : RFp) (t : List Label)
    (owner : Label → Nat) : List (Nat × Nat) := Id.run do
  let g := evGraph p idx
  let reach0 := labelReach p idx localDepth g g.reachRows t.toArray
  let arr := t.toArray
  -- `labelReach` follows paths between labels only a few steps deep: a pair it does not order is
  -- a witness only with a certificate.
  let reach (i j : Nat) : Bool := reach0 i j || !certify p idx arr i j windowFuel
  let em := ends rfp t
  let E (b : Nat) := em.getD b #[]
  let keyOf (buf i j : Nat) : Nat × Nat × Nat :=
    let a := owner arr[i]!
    let b := owner arr[j]!
    (min a b, max a b, buf)
  let mut seen : Std.HashSet (Nat × Nat × Nat) := {}
  let mut out : List (Nat × Nat) := []
  for ((buf, _), L) in (groups (emittedR E rfp t)).toList do
    let mut lw : Option Nat := none
    let mut rs : List Nat := []
    for (j, w) in L.toList do
      if let some i := lw then
        let key := keyOf buf i j
        if i != j && !seen.contains key && !reach i j then
          out := (i, j) :: out
          seen := seen.insert key
      if w then
        for r in rs do
          let key := keyOf buf r j
          if r != j && !seen.contains key && !reach r j then
            out := (r, j) :: out
            seen := seen.insert key
        lw := some j
        rs := []
      else rs := j :: rs
  return out

/-- A position both accesses touch, if any. -/
def commonPos (a b : RAcc) : Option Int :=
  a.ranges.findSome? fun ra => b.ranges.findSome? fun rb =>
    let lo := max ra.1 rb.1
    if lo < min ra.2 rb.2 then some lo else none

/-! ### Footprints computed once -/

/-- The values of `f` on `ls`, computed once. -/
def buildMemo (f : RFp) (ls : List Label) : Std.HashMap Label (List RAcc) :=
  ls.foldl (fun m x => m.insert x (f x)) {}

/-- `f`, looked up in `m` first. Build `m` once (`buildMemo`), outside the calls. -/
def memoWith (m : Std.HashMap Label (List RAcc)) (f : RFp) : RFp := fun x =>
  match m[x]? with
  | some v => v
  | none => f x

theorem memoWith_eq (f : RFp) (ls : List Label) : memoWith (buildMemo f ls) f = f := by
  funext x
  simp only [memoWith, buildMemo]
  suffices H : ∀ (l : List Label) (m : Std.HashMap Label (List RAcc)),
      (∀ y v, m[y]? = some v → v = f y) →
      ∀ v, (l.foldl (fun m x => m.insert x (f x)) m)[x]? = some v → v = f x by
    cases h : (ls.foldl (fun m x => m.insert x (f x)) ({} : Std.HashMap Label (List RAcc)))[x]? with
    | none => rfl
    | some v => exact H ls {} (by simp) v h
  intro l
  induction l with
  | nil => intro m hm v h; exact hm x v h
  | cons y ys ih =>
    intro m hm
    apply ih
    intro z v hz
    rw [Std.HashMap.getElem?_insert] at hz
    split at hz
    · rename_i h; simp only [beq_iff_eq] at h; subst h; exact (Option.some.inj hz).symm
    · exact hm z v hz

end Chan

end

end Veir.Air
