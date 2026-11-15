module

public import Veir.Air.ChanMem
public import Std.Data.HashSet
public import Std.Data.HashMap

namespace Veir.Air

@[expose] public section

/-! # Layer 4: the checks, fast

`Chan.check` and `Chan.racesL` are written to be easy to prove, not to run: the greedy execution
scans every label at every step. Here an execution is proposed by Kahn's algorithm (`genTrace`,
not proven: anything it gets wrong is caught below), then checked in close to linear time by
`checkH`, which is proven:
- `checkH_true`: `some true` means the proposed execution is valid and completes;
- `checkH_false`: `some false` means it is valid and stuck before completing, so (by
  `no_completion_of_stuck`) no execution completes;
- `none`: the proposal was wrong (an internal error, never a wrong verdict).

Fired labels are a `Std.HashSet`; an index lists each event's elements, and is itself checked
(`indexedB`). Races are checked on the positions of the execution (`racesG`, proven sound by
`raceFree_of_racesG`) with any graph whose edges are `hbPreds` edges.
-/

namespace Chan

deriving instance Hashable for Label

abbrev LSet := Std.HashSet Label

/-- `S` holds exactly the labels of `F`. -/
def Rep (S : LSet) (F : List Label) : Prop := ∀ x, S.contains x = true ↔ x ∈ F

theorem Rep.empty : Rep ∅ [] := fun x => by simp

theorem Rep.insert {S : LSet} {F : List Label} {l : Label} (h : Rep S F) :
    Rep (S.insert l) (l :: F) := fun x => by
  rw [Std.HashSet.contains_insert, Bool.or_eq_true, beq_iff_eq, h x, List.mem_cons]
  constructor <;> rintro (h | h) <;> simp_all

theorem Rep.contains {S : LSet} {F : List Label} (h : Rep S F) (x : Label) :
    S.contains x = F.contains x := by
  rw [Bool.eq_iff_iff, h x, List.contains_iff_mem]

variable {p : Prog}

/-! ### Each event's elements -/

/-- `idx[v]` lists every element whose put or get is `v`. -/
def Indexed (p : Prog) (idx : Array (List Nat)) : Prop :=
  ∀ k e v, p.elems[k]? = some e → (e.src = some v ∨ some v ∈ e.dsts) → k ∈ idx.getD v []

def indexedB (p : Prog) (idx : Array (List Nat)) : Bool :=
  (List.range p.elems.size).all fun k =>
    match p.elems[k]? with
    | none => true
    | some e =>
      (match e.src with | none => true | some v => (idx.getD v []).contains k) &&
        e.dsts.all fun o => match o with | none => true | some v => (idx.getD v []).contains k

theorem indexed_of_indexedB {idx : Array (List Nat)} (h : indexedB p idx = true) : Indexed p idx := by
  intro k e v hk hv
  simp only [indexedB, List.all_eq_true, List.mem_range] at h
  have := h k (elem_lt hk)
  rw [hk] at this
  simp only [Bool.and_eq_true] at this
  rcases hv with hv | hv
  · have := this.1; rw [hv] at this; simpa using this
  · have := this.2
    simp only [List.all_eq_true] at this
    simpa using this _ hv

/-! ### Enabledness on a hash set -/

def sentH (S : LSet) (k : Nat) : Bool := S.contains (.push k) || S.contains (.xfer k)
def gotH (S : LSet) (k i : Nat) : Bool := S.contains (.pull k i) || S.contains (.xfer k)

def gotAtH (S : LSet) (e : Elem) (k v : Nat) : Bool :=
  (List.range e.dsts.length).all fun i => e.dsts[i]? != some (some v) || gotH S k i

def allStartedH (S : LSet) (e : Elem) : Bool :=
  !e.dsts.isEmpty && e.dsts.all fun o => match o with | none => false | some d => S.contains (.start d)

def enH (p : Prog) (idx : Array (List Nat)) (S : LSet) : Label → Bool
  | .start v => decide (v < p.graph.size) && (p.graph.predsOf v).all fun u => S.contains (.finish u)
  | .finish v => decide (v < p.graph.size) && S.contains (.start v) &&
      (idx.getD v []).all fun k =>
        match p.elems[k]? with
        | none => true
        | some e => (e.src != some v || sentH S k) && gotAtH S e k v
  | .read k =>
    match p.elems[k]? with
    | none => false
    | some e =>
      (match e.src with | none => false | some s => S.contains (.start s)) &&
        prevB e fun j => S.contains (.read j)
  | .push k =>
    match p.elems[k]? with
    | none => false
    | some e => e.buffered && S.contains (.read k) && prevB e (sentH S)
  | .pull k i =>
    match p.elems[k]? with
    | none => false
    | some e => e.buffered &&
        (match e.dsts[i]? with | some (some d) => S.contains (.start d) | _ => false) &&
        S.contains (.push k) && prevB e (fun j => gotH S j i)
  | .xfer k =>
    match p.elems[k]? with
    | none => false
    | some e => !e.buffered && S.contains (.read k) && allStartedH S e && prevAllB e (gotH S)

theorem enH_iff {idx : Array (List Nat)} {S : LSet} {F : List Label} {l : Label}
    (hi : Indexed p idx) (hr : Rep S F) : enH p idx S l = true ↔ En p F l := by
  have hc := hr.contains
  have hs : ∀ k, sentH S k = sentB F k := fun k => by simp [sentH, sentB, hc]
  have hg : ∀ k i, gotH S k i = gotB F k i := fun k i => by simp [gotH, gotB, hc]
  have hga : ∀ e k v, gotAtH S e k v = gotAtB F e k v := fun e k v => by simp [gotAtH, gotAtB, hg]
  have has : ∀ e, allStartedH S e = allStartedB F e := fun e => by
    simp only [allStartedH, allStartedB]
    congr 1
    apply List.all_congr rfl
    intro o
    cases o <;> simp [hc]
  cases l with
  | finish v =>
    simp only [enH, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true, hc,
      List.contains_iff_mem]
    constructor
    · rintro ⟨⟨hlt, hst⟩, h⟩
      refine ⟨hlt, hst, fun k e hk => ⟨fun hsv => ?_, fun i hdv => ?_⟩⟩
      · have := h k (hi k e v hk (Or.inl hsv))
        rw [hk] at this
        simp only [Bool.and_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq, hsv, not_true_eq_false,
          false_or, hs] at this
        exact sentB_iff.mp this.1
      · have hmem : some v ∈ e.dsts := List.mem_of_getElem? hdv
        have := h k (hi k e v hk (Or.inr hmem))
        rw [hk] at this
        simp only [Bool.and_eq_true, hga] at this
        exact gotAtB_iff.mp this.2 _ hdv
    · rintro ⟨hlt, hst, h⟩
      refine ⟨⟨hlt, hst⟩, fun k _ => ?_⟩
      cases hk : p.elems[k]? with
      | none => rfl
      | some e =>
        have := h k e hk
        simp only [Bool.and_eq_true, Bool.or_eq_true, bne_iff_ne, ne_eq, hs, hga]
        refine ⟨?_, gotAtB_iff.mpr this.2⟩
        by_cases hsv : e.src = some v
        · exact Or.inr (sentB_iff.mpr (this.1 hsv))
        · exact Or.inl hsv
  | start v =>
    rw [← enB_iff]; simp [enH, enB, hc]
  | read k =>
    rw [← enB_iff]
    cases hk : p.elems[k]? with
    | none => simp [enH, enB, hk]
    | some e =>
      simp only [enH, enB, hk]
      cases e.src <;> simp [hc]
  | push k =>
    rw [← enB_iff]
    have hs' : sentH S = sentB F := funext hs
    cases hk : p.elems[k]? <;> simp [enH, enB, hk, hc, hs']
  | pull k i =>
    rw [← enB_iff]
    have hg' : (fun j => gotH S j i) = (fun j => gotB F j i) := funext fun j => hg j i
    cases hk : p.elems[k]? with
    | none => simp [enH, enB, hk]
    | some e =>
      simp only [enH, enB, hk, hg']
      rcases e.dsts[i]? with _ | _ | d <;> simp [hc]
  | xfer k =>
    rw [← enB_iff]
    have hg' : gotH S = gotB F := funext fun j => funext fun i => hg j i
    cases hk : p.elems[k]? with
    | none => simp [enH, enB, hk]
    | some e =>
      simp only [enH, enB, hk, hg', has, hc]

/-! ### Checking a proposed execution -/

/-- Fire `t` in order from `S`, each label once and only when enabled; the final set. -/
def replayH (p : Prog) (idx : Array (List Nat)) : LSet → List Label → Option LSet
  | S, [] => some S
  | S, l :: t => if !S.contains l && enH p idx S l then replayH p idx (S.insert l) t else none

theorem replayH_run {idx : Array (List Nat)} (hi : Indexed p idx) :
    ∀ (t : List Label) (S S' : LSet) (F : List Label), Rep S F → replayH p idx S t = some S' →
      ∃ G, Run p F t G ∧ Rep S' G := by
  intro t
  induction t with
  | nil => intro S S' F hr h; simp only [replayH, Option.some.injEq] at h; subst h; exact ⟨F, .nil F, hr⟩
  | cons l t ih =>
    intro S S' F hr h
    simp only [replayH] at h
    split at h
    · next hc =>
      simp only [Bool.and_eq_true, Bool.not_eq_true'] at hc
      obtain ⟨G, r, hG⟩ := ih (S.insert l) S' (l :: F) hr.insert h
      refine ⟨G, .cons ((enH_iff hi hr).mp hc.2) ?_ r, hG⟩
      intro hl; rw [← hr l, hc.1] at hl; cases hl
    · simp at h

def doneH (p : Prog) (S : LSet) : Bool :=
  (List.range p.graph.size).all fun v => S.contains (.finish v)

def stuckH (p : Prog) (idx : Array (List Nat)) (S : LSet) : Bool :=
  (cands p).all fun l => S.contains l || !enH p idx S l

/-- The verdict on a proposed execution `t`. -/
def checkH (p : Prog) (idx : Array (List Nat)) (t : List Label) : Option Bool :=
  if indexedB p idx then
    match replayH p idx ∅ t with
    | none => none
    | some S => if doneH p S then some true else if stuckH p idx S then some false else none
  else none

/-- **`some true` is right**: `t` is an execution, and it completes. -/
theorem checkH_true {idx : Array (List Nat)} {t : List Label} (h : checkH p idx t = some true) :
    ∃ G, Run p [] t G ∧ Done p G := by
  simp only [checkH] at h
  split at h
  · next hix =>
    split at h
    · simp at h
    · next S hS =>
      obtain ⟨G, r, hG⟩ := replayH_run (indexed_of_indexedB hix) t ∅ S [] Rep.empty hS
      split at h
      · next hd =>
        refine ⟨G, r, fun v hv => ?_⟩
        simp only [doneH, List.all_eq_true, List.mem_range] at hd
        exact (hG _).mp (hd v hv)
      · split at h <;> simp at h
  · simp at h

/-- **`some false` is right**: no execution completes; every execution deadlocks. -/
theorem checkH_false {idx : Array (List Nat)} {t : List Label} (h : checkH p idx t = some false) :
    ¬ ∃ t G, Run p [] t G ∧ Done p G := by
  simp only [checkH] at h
  split at h
  · next hix =>
    have hi := indexed_of_indexedB hix
    split at h
    · simp at h
    · next S hS =>
      obtain ⟨G, r, hG⟩ := replayH_run hi t ∅ S [] Rep.empty hS
      split at h
      · simp at h
      · next hnd =>
        split at h
        · next hst =>
          apply no_completion_of_stuck r
          · intro l hl he
            simp only [stuckH, List.all_eq_true, Bool.or_eq_true, Bool.not_eq_true'] at hst
            rcases hst l (mem_cands he) with h' | h'
            · exact hl ((hG l).mp h')
            · rw [(enH_iff hi hG).mpr he] at h'; cases h'
          · intro hd
            apply hnd
            simp only [doneH, List.all_eq_true, List.mem_range]
            exact fun v hv => (hG _).mpr (hd v hv)
        · simp at h
  · simp at h

/-! ### Races on a proposed execution -/

/-- The conflicting pairs of positions `i < j` of `t` that `g` does not order. -/
def racesG (g : DepGraph) (fp : LFp) (t : List Label) : List (Nat × Nat) :=
  let rows := g.reachRows
  let arr := t.toArray
  (List.range arr.size).flatMap fun j =>
    (List.range j).filterMap fun i =>
      match arr[i]?, arr[j]? with
      | some x, some y =>
        if conflictB fp x y && !g.reachFast rows i j && !g.reachFast rows j i then some (i, j)
        else none
      | _, _ => none

/-- `g`'s edges, on the positions of `t`, are `hbPreds` edges. -/
def HBEdges (p : Prog) (g : DepGraph) (t : List Label) : Prop :=
  ∀ b w, w ∈ g.predsOf b → ∃ y z, t[b]? = some y ∧ z ∈ hbPreds p y ∧ t[w]? = some z

theorem reach_hb_of {g : DepGraph} {t : List Label} (hg : HBEdges p g t) {a b : Nat}
    (r : DepGraph.Reach g a b) : ∀ y, t[b]? = some y → ∃ x, t[a]? = some x ∧ HB p x y := by
  induction r with
  | refl => intro y hy; exact ⟨y, hy, .refl y⟩
  | @step w v _ hp ih =>
    intro y hy
    obtain ⟨y', z, hy', hz, hw⟩ := hg _ _ hp
    rw [hy] at hy'; cases hy'
    obtain ⟨x, hx, hxz⟩ := ih z hw
    exact ⟨x, hx, .step hxz hz⟩

/-- **The race check is sound** for any graph of `hbPreds` edges. -/
theorem raceFree_of_racesG {g : DepGraph} {fp : LFp} {t : List Label} (hg : HBEdges p g t)
    (h : racesG g fp t = []) : RaceFree p fp (· ∈ t) := by
  intro x y hx hy hne hc
  have hi := List.idxOf_lt_length_of_mem hx
  have hj := List.idxOf_lt_length_of_mem hy
  have gx : t[t.idxOf x]? = some x := by
    rw [List.getElem?_eq_getElem hi, List.getElem_idxOf]
  have gy : t[t.idxOf y]? = some y := by
    rw [List.getElem?_eq_getElem hj, List.getElem_idxOf]
  have hij : t.idxOf x ≠ t.idxOf y := fun e => hne (by rw [e] at gx; rw [gx] at gy; cases gy; rfl)
  have key : ∀ i j u w, i < j → j < t.length → t[i]? = some u → t[j]? = some w →
      LConflict fp u w → (DepGraph.Reach g i j ∨ DepGraph.Reach g j i) := by
    intro i j u w hij hj hu hw hcf
    have hnot : (i, j) ∉ racesG g fp t := by rw [h]; simp
    simp only [racesG, List.mem_flatMap, List.mem_range, List.mem_filterMap, List.size_toArray,
      List.getElem?_toArray, not_exists, not_and] at hnot
    have := hnot j hj i hij
    rw [hu, hw] at this
    simp only [conflictB_iff.mpr hcf, Bool.true_and, DepGraph.reachFast_eq] at this
    by_cases r1 : g.reachB i j = true
    · exact Or.inl (DepGraph.reach_of_reachB r1)
    · by_cases r2 : g.reachB j i = true
      · exact Or.inr (DepGraph.reach_of_reachB r2)
      · simp [r1, r2] at this
  rcases Nat.lt_or_gt_of_ne hij with hlt | hlt
  · rcases key _ _ x y hlt hj gx gy hc with r | r
    · obtain ⟨x', hx', hb⟩ := reach_hb_of hg r y gy
      rw [gx] at hx'; cases hx'; exact Or.inl hb
    · obtain ⟨y', hy', hb⟩ := reach_hb_of hg r x gx
      rw [gy] at hy'; cases hy'; exact Or.inr hb
  · rcases key _ _ y x hlt hi gy gx hc.symm with r | r
    · obtain ⟨y', hy', hb⟩ := reach_hb_of hg r x gx
      rw [gy] at hy'; cases hy'; exact Or.inr hb
    · obtain ⟨x', hx', hb⟩ := reach_hb_of hg r y gy
      rw [gx] at hx'; cases hx'; exact Or.inl hb

/-- `hbPreds`, with `finish v` reading the index instead of scanning every element. -/
def hbPredsI (p : Prog) (idx : Array (List Nat)) : Label → List Label
  | .finish v => .start v :: (idx.getD v []).flatMap fun k =>
      match p.elems[k]? with
      | none => []
      | some e => (if e.src = some v then [sentLabel p k] else []) ++
          (List.range e.dsts.length).filterMap fun i =>
            if e.dsts[i]? = some (some v) then some (gotLabel p k i) else none
  | l => hbPreds p l

theorem hbPredsI_sub {idx : Array (List Nat)} {l z : Label} (h : z ∈ hbPredsI p idx l) :
    z ∈ hbPreds p l := by
  cases l with
  | finish v =>
    simp only [hbPredsI, List.mem_cons, List.mem_flatMap] at h
    simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range]
    rcases h with h | ⟨k, _, hz⟩
    · exact Or.inl h
    · cases hk : p.elems[k]? with
      | none => simp [hk] at hz
      | some e => exact Or.inr ⟨k, elem_lt hk, by simpa [hk] using hz⟩
  | _ => exact h

/-- The graph of `hbPredsI` on the positions of `t`, through an index `ix` of positions; an edge
is kept only if `ix` is right about it, so `ix` need not be trusted. -/
def posGraphH (p : Prog) (idx : Array (List Nat)) (t : List Label) (ix : Std.HashMap Label Nat) :
    DepGraph :=
  let arr := t.toArray
  ⟨arr.map fun l => (hbPredsI p idx l).filterMap fun z =>
    match ix[z]? with
    | some w => if arr[w]? == some z then some w else none
    | none => none⟩

theorem hbEdges_posGraphH {idx : Array (List Nat)} {t : List Label} {ix : Std.HashMap Label Nat} :
    HBEdges p (posGraphH p idx t ix) t := by
  intro b w h
  simp only [DepGraph.predsOf, posGraphH, Array.getElem?_map, List.getElem?_toArray] at h
  cases hb : t[b]? with
  | none => simp [hb] at h
  | some y =>
    simp only [hb, Option.map_some, Option.getD_some, List.mem_filterMap] at h
    obtain ⟨z, hz, hw⟩ := h
    split at hw
    · split at hw
      · next hz' =>
        simp only [Option.some.injEq] at hw
        subst hw
        simp only [beq_iff_eq] at hz'
        exact ⟨y, z, rfl, hbPredsI_sub hz, hz'⟩
      · simp at hw
    · simp at hw

/-! ### Races, location by location

Checking every pair of labels is quadratic. Instead, for each location, scan its accesses in
execution order: each access must come after the last write (in `HB`), and a write after every read
since that write. By transitivity every conflicting pair is then ordered (`scanOk_sound`). -/

abbrev Entry := Loc × Nat × Bool

/-- Every access of every label of `t`: its location, the label's position, and whether it
writes. -/
def emitted (fp : LFp) (t : List Label) : List Entry :=
  t.zipIdx.flatMap fun (x, i) =>
    (fp x).flatMap fun a => a.elems.map fun el => ((a.buf, el), i, a.kind == .write)

def groupStep (m : Std.HashMap Loc (Array (Nat × Bool))) (e : Entry) :
    Std.HashMap Loc (Array (Nat × Bool)) :=
  m.insert e.1 ((m.getD e.1 #[]).push e.2)

/-- The accesses of each location, in execution order. -/
def groups (es : List Entry) : Std.HashMap Loc (Array (Nat × Bool)) := es.foldl groupStep {}

theorem groups_spec (es : List Entry) (m₀ : Std.HashMap Loc (Array (Nat × Bool))) (l : Loc) :
    ((es.foldl groupStep m₀).getD l #[]).toList =
      (m₀.getD l #[]).toList ++ (es.filter fun e => e.1 == l).map (·.2) := by
  induction es generalizing m₀ with
  | nil => simp
  | cons e es ih =>
    rw [List.foldl_cons, ih]
    simp only [groupStep, Std.HashMap.getD_insert, List.filter_cons]
    by_cases h : e.1 = l
    · subst h; simp
    · have h' : (e.1 == l) = false := by simpa using h
      simp [h']

/-- The scan of one location's accesses. `last` is the last position seen, `lw` the last write,
`rs` the reads since it. -/
def scanOk (reach : Nat → Nat → Bool) : Nat → Option Nat → List Nat → List (Nat × Bool) → Bool
  | _, _, _, [] => true
  | last, lw, rs, (j, w) :: rest =>
    decide (last ≤ j) &&
    (match lw with | some i => reach i j | none => true) &&
    (!w || rs.all fun r => reach r j) &&
    (if w then scanOk reach j (some j) [] rest else scanOk reach j lw (j :: rs) rest)

/-- Conflicting accesses of `P` at different positions are ordered by `R`. -/
def PairsOk (R : Nat → Nat → Prop) (P : List (Nat × Bool)) : Prop :=
  ∀ e ∈ P, ∀ f ∈ P, e.1 < f.1 → (e.2 = true ∨ f.2 = true) → R e.1 f.1

structure ScanInv (R : Nat → Nat → Prop) (P : List (Nat × Bool)) (last : Nat) (lw : Option Nat)
    (rs : List Nat) : Prop where
  sorted : ∀ e ∈ P, e.1 ≤ last
  writes : ∀ e ∈ P, e.2 = true → ∃ i, lw = some i ∧ R e.1 i
  reads : ∀ e ∈ P, e.2 = false → e.1 ∈ rs ∨ ∃ i, lw = some i ∧ R e.1 i
  pairs : PairsOk R P

theorem scanOk_sound {R : Nat → Nat → Prop} {reach : Nat → Nat → Bool}
    (hrefl : ∀ i, R i i) (htrans : ∀ a b c, R a b → R b c → R a c)
    (hsound : ∀ i j, reach i j = true → R i j) :
    ∀ (L P : List (Nat × Bool)) (last : Nat) (lw : Option Nat) (rs : List Nat),
      scanOk reach last lw rs L = true → ScanInv R P last lw rs → PairsOk R (P ++ L) := by
  intro L
  induction L with
  | nil => intro P _ _ _ _ hi; simpa using hi.pairs
  | cons f L ih =>
    obtain ⟨j, w⟩ := f
    intro P last lw rs h hi
    simp only [scanOk, Bool.and_eq_true, decide_eq_true_eq, Bool.or_eq_true, Bool.not_eq_true',
      List.all_eq_true] at h
    obtain ⟨⟨⟨hlast, hlw⟩, hrs⟩, hrest⟩ := h
    have tolw : ∀ i, lw = some i → R i j := by
      intro i hi'; subst hi'; exact hsound _ _ hlw
    -- Everything of `P` that conflicts with the new access is ordered before it.
    have before : ∀ e ∈ P, (e.2 = true ∨ w = true) → R e.1 j := by
      intro e he hw
      cases hew : e.2 with
      | true =>
        obtain ⟨i, hi', hr⟩ := hi.writes e he hew
        exact htrans _ _ _ hr (tolw i hi')
      | false =>
        have hw : w = true := by rcases hw with h | h <;> simp_all
        rcases hi.reads e he hew with hin | ⟨i, hi', hr⟩
        · rcases hrs with h | h
          · rw [hw] at h; cases h
          · exact hsound _ _ (h _ hin)
        · exact htrans _ _ _ hr (tolw i hi')
    have pairs' : PairsOk R (P ++ [(j, w)]) := by
      intro e he f hf hlt hw
      simp only [List.mem_append, List.mem_singleton] at he hf
      rcases he with he | rfl <;> rcases hf with hf | rfl
      · exact hi.pairs e he f hf hlt hw
      · exact before e he hw
      · exact absurd (Nat.lt_of_lt_of_le hlt (Nat.le_trans (hi.sorted f hf) hlast)) (Nat.lt_irrefl _)
      · exact absurd hlt (Nat.lt_irrefl _)
    have sorted' : ∀ e ∈ P ++ [(j, w)], e.1 ≤ j := by
      intro e he
      simp only [List.mem_append, List.mem_singleton] at he
      rcases he with he | rfl
      · exact Nat.le_trans (hi.sorted e he) hlast
      · exact Nat.le_refl _
    have := ih (P ++ [(j, w)]) j
    simp only [List.append_assoc, List.cons_append, List.nil_append] at this
    cases w with
    | true =>
      simp only [ite_true] at hrest
      apply this (some j) [] hrest
      refine ⟨sorted', fun e he _ => ⟨j, rfl, ?_⟩, fun e he _ => Or.inr ⟨j, rfl, ?_⟩, pairs'⟩
      · simp only [List.mem_append, List.mem_singleton] at he
        rcases he with he | rfl
        · exact before e he (Or.inr rfl)
        · exact hrefl _
      · simp only [List.mem_append, List.mem_singleton] at he
        rcases he with he | rfl
        · exact before e he (Or.inr rfl)
        · exact hrefl _
    | false =>
      simp only [Bool.false_eq_true, ite_false] at hrest
      apply this lw (j :: rs) hrest
      refine ⟨sorted', fun e he hew => ?_, fun e he hew => ?_, pairs'⟩
      · simp only [List.mem_append, List.mem_singleton] at he
        rcases he with he | rfl
        · exact hi.writes e he hew
        · cases hew
      · simp only [List.mem_append, List.mem_singleton] at he
        rcases he with he | rfl
        · rcases hi.reads e he hew with h | h
          · exact Or.inl (List.mem_cons_of_mem _ h)
          · exact Or.inr h
        · exact Or.inl (List.mem_cons_self ..)

/-- The race check, location by location. -/
def racesOk (g : DepGraph) (fp : LFp) (t : List Label) : Bool :=
  let reach := g.reachFast g.reachRows
  (groups (emitted fp t)).toList.all fun (_, arr) => scanOk reach 0 none [] arr.toList

theorem mem_emitted {fp : LFp} {t : List Label} {x : Label} {i : Nat} {a : Access} {el : Int}
    (hx : t[i]? = some x) (ha : a ∈ fp x) (hel : el ∈ a.elems) :
    ((a.buf, el), i, a.kind == .write) ∈ emitted fp t := by
  simp only [emitted, List.mem_flatMap, List.mem_map]
  exact ⟨(x, i), List.mem_zipIdx_iff_getElem?.mpr hx, a, ha, el, hel, rfl⟩

theorem group_mem {fp : LFp} {t : List Label} {e : Entry} (he : e ∈ emitted fp t) :
    e.2 ∈ ((groups (emitted fp t)).getD e.1 #[]).toList := by
  rw [groups, groups_spec]
  simp only [Std.HashMap.getD_empty, Array.toList_empty, List.nil_append, List.mem_map,
    List.mem_filter, beq_iff_eq]
  exact ⟨e, ⟨he, rfl⟩, rfl⟩

/-- **The location-by-location race check is sound.** -/
theorem raceFree_of_racesOk {g : DepGraph} {fp : LFp} {t : List Label} (hg : HBEdges p g t)
    (h : racesOk g fp t = true) : RaceFree p fp (· ∈ t) := by
  intro x y hx hy hne hc
  obtain ⟨a, ha, b, hb, hbuf, hw, el, hela, helb⟩ := hc
  have gx : t[t.idxOf x]? = some x := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hx), List.getElem_idxOf]
  have gy : t[t.idxOf y]? = some y := by
    rw [List.getElem?_eq_getElem (List.idxOf_lt_length_of_mem hy), List.getElem_idxOf]
  have hij : t.idxOf x ≠ t.idxOf y := fun e => hne (by rw [e] at gx; rw [gx] at gy; cases gy; rfl)
  -- Both accesses are in the group of location (a.buf, el), which the scan accepted.
  have ex := group_mem (mem_emitted gx ha hela)
  have ey := group_mem (mem_emitted gy hb helb)
  simp only at ex ey
  rw [← hbuf] at ey
  let l : Loc := (a.buf, el)
  have hscan : scanOk (g.reachFast g.reachRows) 0 none [] ((groups (emitted fp t)).getD l #[]).toList
      = true := by
    rw [Std.HashMap.getD_eq_getD_getElem?]
    cases hl : (groups (emitted fp t))[l]? with
    | none => simp [scanOk]
    | some arr =>
      simp only [racesOk, List.all_eq_true] at h
      exact h (l, arr) (Std.HashMap.mem_toList_iff_getElem?_eq_some.mpr hl)
  have pairs := scanOk_sound (R := DepGraph.Reach g) (fun i => .refl i)
    (fun _ _ _ h₁ h₂ => h₁.trans h₂)
    (fun i j h => by rw [DepGraph.reachFast_eq] at h; exact DepGraph.reach_of_reachB h)
    _ [] 0 none [] hscan ⟨by simp, by simp, by simp, by simp [PairsOk]⟩
  simp only [List.nil_append] at pairs
  have hwr : (a.kind == .write) = true ∨ (b.kind == .write) = true := by
    rcases hw with h | h <;> simp [h]
  rcases Nat.lt_or_gt_of_ne hij with hlt | hlt
  · have r := pairs _ ex _ ey hlt hwr
    obtain ⟨x', hx', hb'⟩ := reach_hb_of hg r y gy
    rw [gx] at hx'; cases hx'; exact Or.inl hb'
  · have r := pairs _ ey _ ex hlt hwr.symm
    obtain ⟨y', hy', hb'⟩ := reach_hb_of hg r x gx
    rw [gy] at hy'; cases hy'; exact Or.inr hb'

/-- Witnesses for a failed scan: the pairs of positions it found unordered (not proven; only for
messages). -/
def scanReport (reach : Nat → Nat → Bool) (L : List (Nat × Bool)) : List (Nat × Nat) := Id.run do
  let mut lw : Option Nat := none
  let mut rs : List Nat := []
  let mut out : List (Nat × Nat) := []
  for (j, w) in L do
    if let some i := lw then
      if i != j && !reach i j then out := (i, j) :: out
    if w then
      for r in rs do
        if r != j && !reach r j then out := (r, j) :: out
      lw := some j
      rs := []
    else rs := j :: rs
  return out

def raceWitnesses (g : DepGraph) (fp : LFp) (t : List Label) : List (Nat × Nat) :=
  let reach := g.reachFast g.reachRows
  ((groups (emitted fp t)).toList.flatMap fun (_, arr) => scanReport reach arr.toList).eraseDups

/-! ### What the fast check buys -/

/-- **The fast check, end to end.** If `checkH` accepts a proposed execution `t` as complete and
`racesOk` finds no race on it, every complete execution of the program ends with the memory `t`
ends with. -/
theorem outcome_uniqueH {V : Type} {fp : LFp} {eff : Label → Mem V → Mem V} {idx : Array (List Nat)}
    {ix : Std.HashMap Label Nat} {t : List Label} (hw : WF p) (hfr : LFramed fp eff)
    (hc : checkH p idx t = some true) (hr : racesOk (posGraphH p idx t ix) fp t = true)
    {t' G : List Label} (h : Run p [] t' G) (d : Done p G) (m : Mem V) :
    runL eff t' m = runL eff t m := by
  obtain ⟨G₀, r, d₀⟩ := checkH_true hc
  exact (deterministic hw hfr r d₀ h d (raceFree_of_racesOk hbEdges_posGraphH hr) m).symm

/-! ### Proposing an execution (not proven; checked by `checkH`) -/

/-- Whether a label can fire in some execution, judging by its element alone. -/
def possible (p : Prog) : Label → Bool
  | .start v | .finish v => decide (v < p.graph.size)
  | .read k => match p.elems[k]? with | some e => e.src.isSome | none => false
  | .push k => match p.elems[k]? with | some e => e.buffered && e.src.isSome | none => false
  | .pull k i => match p.elems[k]? with
    | some e => e.buffered && e.src.isSome && (match e.dsts[i]? with | some (some _) => true | _ => false)
    | none => false
  | .xfer k => match p.elems[k]? with
    | some e => !e.buffered && e.src.isSome && !e.dsts.isEmpty && e.dsts.all (·.isSome)
    | none => false

/-- Kahn's algorithm on `hbPredsI`, plus `extra` orderings: fire each possible label once all it
needs has fired. -/
def genTraceWith (p : Prog) (idx : Array (List Nat)) (extra : Label → List Label) : List Label := Id.run do
  let labels := (cands p).filter (possible p)
  let mut cnt : Std.HashMap Label Nat := {}
  let mut succ : Std.HashMap Label (List Label) := {}
  for l in labels do
    let ps := (hbPredsI p idx l ++ extra l).eraseDups
    cnt := cnt.insert l ps.length
    for z in ps do
      succ := succ.insert z (l :: succ.getD z [])
  let mut stack : Array Label := (labels.filter fun l => cnt.getD l 0 == 0).toArray
  let mut out : Array Label := #[]
  for _ in [0:labels.length] do
    let some l := stack.back? | break
    stack := stack.pop
    out := out.push l
    for s in succ.getD l [] do
      let c := cnt.getD s 0 - 1
      cnt := cnt.insert s c
      if c == 0 && cnt.contains s then stack := stack.push s
  return out.toList

def genTrace (p : Prog) (idx : Array (List Nat)) : List Label := genTraceWith p idx fun _ => []

/-- An execution in which `y` fires before `x` (for a race between them), if there is one. -/
def altTrace (p : Prog) (idx : Array (List Nat)) (x y : Label) : Option (List Label) :=
  let t := genTraceWith p idx fun l => if l == x then [y] else []
  if checkH p idx t == some true then some t else none

/-- Each event's elements. -/
def buildIndex (p : Prog) : Array (List Nat) := Id.run do
  let mut idx : Array (List Nat) := Array.replicate p.graph.size []
  for e in p.elems, k in [0:p.elems.size] do
    if let some v := e.src then idx := idx.modify v (k :: ·)
    for o in e.dsts.eraseDups do
      if let some v := o then
        if e.src != some v then idx := idx.modify v (k :: ·)
  return idx

/-- Positions of the labels of `t`. -/
def positions (t : List Label) : Std.HashMap Label Nat :=
  t.zipIdx.foldl (fun m (l, i) => m.insert l i) {}

end Chan

end

end Veir.Air
