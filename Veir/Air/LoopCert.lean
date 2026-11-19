module

public import Veir.Air.ChanEventReach
public import Std.Data.HashMap.Lemmas
public import Std.Data.HashSet.Lemmas

namespace Veir.Air

@[expose] public section

/-! # Race-freedom for every loop bound (phase 2a, `SCALE_DESIGN.md` §3.1)

A *template* is a program in which each event inside a loop appears once; an *instance* is an
event with an iteration for each loop around it. For every assignment `n` of trip counts, the
template stands for the program of all its instances. This file proves, without instantiating,
that every such program is race-free, from a certificate checked on the template.

## Paths for every bound

`Rel` says how the iterations of one loop relate at the two ends of an edge or of a path; a
*fact* says that for every `n` satisfying its guard, every instance of one event reaches every
instance of another whose iterations relate as its pattern says. Facts start from the template's
edges and close under composition (`compRel`: per loop, the intermediate iteration always exists),
the chain rule and union.
-/

namespace LoopCert

/-- How the iterations of one loop relate at the two ends of an edge or a path: `i` at the source,
`j` at the target, each present when that end is inside the loop. -/
inductive Rel where
  /-- Both ends, the same iteration. -/
  | eq
  /-- Both ends, the target in the next iteration. -/
  | succ
  /-- Both ends, the target in a later iteration. -/
  | lt
  /-- Both ends, the target in the same or a later iteration. -/
  | le
  /-- Any iterations (also when an end is outside the loop). -/
  | any
  /-- Only the target is inside: its first iteration. -/
  | first
  /-- Only the source is inside: its last iteration. -/
  | last
deriving DecidableEq, Repr, Inhabited, Hashable

/-- An iteration when that end is inside the loop. -/
def side (inside : Bool) (i : Nat) : Option Nat := if inside then some i else none

/-- Whether `r` holds of the source's iteration `i` and the target's `j`, for a loop of `n`
iterations. -/
def Rel.holds : Rel → Nat → Option Nat → Option Nat → Bool
  | .eq, _, some i, some j => i == j
  | .succ, _, some i, some j => j == i + 1
  | .lt, _, some i, some j => decide (i < j)
  | .le, _, some i, some j => decide (i ≤ j)
  | .any, _, _, _ => true
  | .first, _, none, some j => j == 0
  | .last, n, some i, none => i + 1 == n
  | _, _, _, _ => false

/-- The composition of `r₁` (source to middle) and `r₂` (middle to target) on one loop, given which
of source, target and middle are inside it: a relation between source and target such that, for
every pair it relates, a middle iteration relating to both exists (`compRel_ok`). `none` when no
such relation is kept. -/
def compRel (inA inB inC : Bool) (r₁ r₂ : Rel) : Option Rel :=
  match inA, inB, inC, r₁, r₂ with
  -- Source, target and middle inside.
  | true, true, true, .eq, r => if r = .first ∨ r = .last then none else some r
  | true, true, true, r, .eq => if r = .first ∨ r = .last then none else some r
  | true, true, true, .le, .succ => some .lt
  | true, true, true, .succ, .le => some .lt
  | true, true, true, .le, .lt => some .lt
  | true, true, true, .lt, .le => some .lt
  | true, true, true, .le, .le => some .le
  | true, true, true, .le, .any => some .any
  | true, true, true, .any, .le => some .any
  | true, true, true, .any, .any => some .any
  -- Source and middle inside: leaving the loop.
  | true, false, true, .eq, .last => some .last
  | true, false, true, .eq, .any => some .any
  | true, false, true, .le, .last => some .any
  | true, false, true, .le, .any => some .any
  | true, false, true, .any, .any => some .any
  -- Middle and target inside: entering it.
  | false, true, true, .first, .eq => some .first
  | false, true, true, .any, .eq => some .any
  | false, true, true, .first, .le => some .any
  | false, true, true, .any, .le => some .any
  | false, true, true, .any, .any => some .any
  -- Source and target inside, the path leaves the loop and comes back.
  | true, true, false, .any, .any => some .any
  -- Only the source, or only the target, is inside: the middle is not concerned.
  | true, false, false, r, .any => if r = .last ∨ r = .any then some r else none
  | false, true, false, .any, r => if r = .first ∨ r = .any then some r else none
  -- Only the middle is inside: it needs an iteration (the guard asks the loop not to be empty).
  | false, false, true, .any, .any => some .any
  | false, false, true, .first, .any => some .any
  | false, false, true, .any, .last => some .any
  -- No end inside.
  | false, false, false, .any, .any => some .any
  | _, _, _, _, _ => none

/-- **Composition is sound on one loop**: for source and target iterations the composed relation
relates, a middle iteration exists that relates to both, within the loop's bound. -/
theorem compRel_ok {inA inB inC : Bool} {r₁ r₂ r : Rel} (h : compRel inA inB inC r₁ r₂ = some r)
    {n i j : Nat} (hi : inA = true → i < n) (hj : inB = true → j < n)
    (hn : inC = true → inA = false → inB = false → 0 < n)
    (hr : r.holds n (side inA i) (side inB j) = true) :
    ∃ k, (inC = true → k < n) ∧ r₁.holds n (side inA i) (side inC k) = true ∧
      r₂.holds n (side inC k) (side inB j) = true := by
  cases inA <;> cases inB <;> cases inC <;> cases r₁ <;> cases r₂ <;>
    simp only [compRel, reduceCtorEq, or_self, ite_false, ite_true, Option.some.injEq,
      or_false, or_true] at h <;>
    (try subst h) <;>
    simp only [side, ite_true, ite_false, Rel.holds, beq_iff_eq, decide_eq_true_eq,
      Bool.false_eq_true, forall_const, Bool.true_eq_false, false_implies, true_and,
      and_true] at hr hi hj hn ⊢
  all_goals first
    | exact ⟨0, by omega⟩
    | exact ⟨i, by omega⟩
    | exact ⟨j, by omega⟩
    | exact ⟨j - 1, by omega⟩
    | exact ⟨i + 1, by omega⟩
    | exact ⟨n - 1, by omega⟩

/-! ### Templates, instances and facts -/

/-- Per template event, the loops around it. -/
abbrev Loops := Array (List Nat)

def inL (ls : Loops) (v L : Nat) : Bool := (ls[v]?.getD []).contains L

/-- An instance's iterations, one per loop (only its own loops matter). -/
abbrev Iter := Nat → Nat

/-- Every iteration of the event's loops within the loop's bound. -/
def Valid (ls : Loops) (n : Nat → Nat) (v : Nat) (it : Iter) : Prop :=
  ∀ L, inL ls v L = true → it L < n L

/-- A pattern: a relation per loop, `any` for loops it does not list. -/
abbrev Pat := List (Nat × Rel)

def Pat.get (π : Pat) (L : Nat) : Rel := ((π.find? (·.1 == L)).map (·.2)).getD .any

def Matches (ls : Loops) (n : Nat → Nat) (π : Pat) (a : Nat) (ia : Iter) (b : Nat) (ib : Iter) :
    Prop :=
  ∀ L, (π.get L).holds (n L) (side (inL ls a L) (ia L)) (side (inL ls b L) (ib L)) = true

/-- Which loops have no iteration (`true`) or some (`false`). -/
abbrev Guard := List (Nat × Bool)

def GuardOk (n : Nat → Nat) (g : Guard) : Prop := ∀ x ∈ g, (n x.1 == 0) = x.2

/-- Every instance of `src` reaches every instance of `dst` that `pat` relates to it, for every
`n` satisfying `guard`. -/
structure Fact where
  src : Nat
  dst : Nat
  pat : Pat
  guard : Guard
deriving BEq, Repr, Inhabited, Hashable

/-- What a fact claims, for a reachability `R` between instances. -/
def Fact.Holds (ls : Loops) (n : Nat → Nat) (R : Nat → Iter → Nat → Iter → Prop) (f : Fact) :
    Prop :=
  GuardOk n f.guard → ∀ ia ib, Valid ls n f.src ia → Valid ls n f.dst ib →
    Matches ls n f.pat f.src ia f.dst ib → R f.src ia f.dst ib

/-- The pattern relating each loop of `keys` by `rel`, and every other loop by `any`. -/
def buildPat (keys : List Nat) (rel : Nat → Rel) : Pat :=
  (keys.filter (rel · != .any)).map fun L => (L, rel L)

theorem buildPat_get {keys : List Nat} {rel : Nat → Rel} (h : ∀ L, L ∉ keys → rel L = .any)
    (L : Nat) : (buildPat keys rel).get L = rel L := by
  simp only [buildPat, Pat.get, List.find?_map]
  cases hf : List.find? ((fun x => x.1 == L) ∘ fun L => (L, rel L)) (keys.filter (rel · != .any)) with
  | some L' =>
    have := List.find?_some hf
    simp only [Function.comp, beq_iff_eq] at this
    subst this; rfl
  | none =>
    simp only [Option.map_none, Option.getD_none]
    by_cases hk : L ∈ keys
    · by_cases hr : rel L = .any
      · exact hr.symm
      · have hm : L ∈ keys.filter (rel · != .any) := List.mem_filter.mpr ⟨hk, by simp [hr]⟩
        have := List.find?_eq_none.mp hf L hm
        simp at this
    · exact (h L hk).symm

/-- The loops a composition must look at. -/
def compKeys (ls : Loops) (f g : Fact) : List Nat :=
  (ls[f.src]?.getD []) ++ (ls[g.dst]?.getD []) ++ (ls[f.dst]?.getD []) ++ f.pat.map (·.1) ++
    g.pat.map (·.1)

theorem Pat.get_of_not_mem {π : Pat} {L : Nat} (h : L ∉ π.map (·.1)) : π.get L = .any := by
  simp only [Pat.get]
  cases hf : π.find? (·.1 == L) with
  | none => rfl
  | some x =>
    have h1 := List.find?_some hf
    have h2 := List.mem_of_find?_eq_some hf
    simp only [beq_iff_eq] at h1
    exact absurd (List.mem_map.mpr ⟨x, h2, h1⟩) h

/-- Sorted, without repeats: so that equal claims are equal facts. -/
def normKeys (ks : List Nat) : List Nat := (ks.mergeSort (· ≤ ·)).eraseDups

theorem mem_normKeys {ks : List Nat} {L : Nat} : L ∈ normKeys ks ↔ L ∈ ks := by
  simp [normKeys, List.mem_eraseDups, List.mem_mergeSort]

def normPat (π : Pat) : Pat := buildPat (normKeys (π.map (·.1))) π.get

theorem normPat_get (π : Pat) (L : Nat) : (normPat π).get L = π.get L :=
  buildPat_get (fun _ h => Pat.get_of_not_mem (by rwa [mem_normKeys] at h)) L

def normGuard (g : Guard) : Guard :=
  (g.mergeSort fun x y => x.1 < y.1 || (x.1 == y.1 && (!x.2 || y.2))).eraseDups

theorem mem_normGuard {g : Guard} {x : Nat × Bool} : x ∈ normGuard g ↔ x ∈ g := by
  simp [normGuard, List.mem_eraseDups, List.mem_mergeSort]

theorem inL_of_not_mem {ls : Loops} {v L : Nat} (h : L ∉ ls[v]?.getD []) : inL ls v L = false := by
  simp [inL, h]

/-- `f` then `g`: per loop, `compRel`; a loop only the middle event is in must not be empty. -/
def compose (ls : Loops) (f g : Fact) : Option Fact :=
  if f.dst != g.src then none else
  let keys := compKeys ls f g
  let rel (L : Nat) := compRel (inL ls f.src L) (inL ls g.dst L) (inL ls f.dst L) (f.pat.get L)
    (g.pat.get L)
  if keys.all (fun L => (rel L).isSome) then
    let midOnly := (ls[f.dst]?.getD []).filter fun L => !inL ls f.src L && !inL ls g.dst L
    some { src := f.src, dst := g.dst, pat := buildPat (normKeys keys) fun L => (rel L).getD .any,
           guard := normGuard (f.guard ++ g.guard ++ midOnly.map (·, false)) }
  else none

/-- **Composition is sound**: through a middle instance that exists for every pair related. -/
theorem compose_holds {ls : Loops} {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
    (htrans : ∀ a ia c ic b ib, R a ia c ic → R c ic b ib → R a ia b ib)
    {f g h : Fact} (hc : compose ls f g = some h) (hf : f.Holds ls n R) (hg : g.Holds ls n R) :
    h.Holds ls n R := by
  simp only [compose, bne_iff_ne, ne_eq, ite_not] at hc
  split at hc
  case isFalse => cases hc
  case isTrue hm =>
  split at hc
  case isFalse => cases hc
  case isTrue hall =>
  cases hc
  intro hgd ia ib hva hvb hmt
  simp only [GuardOk, mem_normGuard, List.mem_append, List.mem_map, List.mem_filter] at hgd
  -- The relation per loop, as `compRel` gives it.
  have hrel : ∀ L, compRel (inL ls f.src L) (inL ls g.dst L) (inL ls f.dst L) (f.pat.get L)
      (g.pat.get L) = some ((buildPat (normKeys (compKeys ls f g)) fun L => (compRel (inL ls f.src L)
        (inL ls g.dst L) (inL ls f.dst L) (f.pat.get L) (g.pat.get L)).getD .any).get L) := by
    intro L
    rw [buildPat_get]
    · by_cases hk : L ∈ compKeys ls f g
      · have := List.all_eq_true.mp hall L hk
        obtain ⟨r, hr⟩ := Option.isSome_iff_exists.mp this
        simp [hr]
      · simp only [compKeys, List.mem_append, not_or] at hk
        obtain ⟨⟨⟨⟨ha, hb⟩, hcm⟩, hfp⟩, hgp⟩ := hk
        rw [inL_of_not_mem ha, inL_of_not_mem hb, inL_of_not_mem hcm, Pat.get_of_not_mem hfp,
          Pat.get_of_not_mem hgp]
        rfl
    · intro L hk
      rw [mem_normKeys] at hk
      simp only [compKeys, List.mem_append, not_or] at hk
      obtain ⟨⟨⟨⟨ha, hb⟩, hcm⟩, hfp⟩, hgp⟩ := hk
      rw [inL_of_not_mem ha, inL_of_not_mem hb, inL_of_not_mem hcm, Pat.get_of_not_mem hfp,
        Pat.get_of_not_mem hgp]
      rfl
  -- A middle iteration per loop.
  have hex : ∀ L, ∃ k, (inL ls f.dst L = true → k < n L) ∧
      (f.pat.get L).holds (n L) (side (inL ls f.src L) (ia L)) (side (inL ls f.dst L) k) = true ∧
      (g.pat.get L).holds (n L) (side (inL ls f.dst L) k) (side (inL ls g.dst L) (ib L)) = true := by
    intro L
    refine compRel_ok (hrel L) (hva L) (hvb L) ?_ (hmt L)
    intro hcL haL hbL
    have hL : L ∈ ls[f.dst]?.getD [] := by simpa [inL] using hcL
    have := hgd (L, false) (Or.inr ⟨L, ⟨hL, by simp [haL, hbL]⟩, rfl⟩)
    simp only [beq_eq_false_iff_ne, ne_eq] at this
    omega
  let ic : Iter := fun L => Classical.choose (hex L)
  have hic : ∀ L, _ := fun L => Classical.choose_spec (hex L)
  have r1 := hf (fun x hx => hgd x (Or.inl (Or.inl hx))) ia ic hva (fun L hL => (hic L).1 hL)
    (fun L => (hic L).2.1)
  have r2 := hg (fun x hx => hgd x (Or.inl (Or.inr hx))) ic ib (by rw [← hm]; exact fun L hL => (hic L).1 hL)
    hvb (by rw [← hm]; exact fun L => (hic L).2.2)
  rw [hm] at r1
  exact htrans _ _ _ _ _ _ r1 r2

/-- `π` with loop `L` related by `r`. -/
def Pat.set (π : Pat) (L : Nat) (r : Rel) : Pat := (L, r) :: π.filter (·.1 != L)

theorem find?_filter_ne (xs : Pat) {L L' : Nat} (h : L' ≠ L) :
    (xs.filter (·.1 != L)).find? (·.1 == L') = xs.find? (·.1 == L') := by
  induction xs with
  | nil => rfl
  | cons x xs ih =>
    by_cases hx : x.1 = L'
    · have hxL : x.1 ≠ L := by omega
      rw [List.filter_cons_of_pos (by simp [hxL]), List.find?_cons_of_pos (by simp [hx]),
        List.find?_cons_of_pos (by simp [hx])]
    · by_cases hx2 : x.1 = L
      · rw [List.filter_cons_of_neg (by simp [hx2]), ih, List.find?_cons_of_neg (by simp [hx])]
      · rw [List.filter_cons_of_pos (by simp [hx2]), List.find?_cons_of_neg (by simp [hx]),
          List.find?_cons_of_neg (by simp [hx]), ih]

theorem Pat.get_set (π : Pat) (L : Nat) (r : Rel) (L' : Nat) :
    (π.set L r).get L' = if L' = L then r else π.get L' := by
  by_cases h : L' = L
  · subst h; simp [Pat.set, Pat.get]
  · have hne : (L == L') = false := by simp; omega
    simp only [Pat.set, Pat.get, List.find?_cons, hne, h, ite_false, find?_filter_ne π h]

/-- The chain rule: an instance reaching the same event's next iteration of `L` (the same
iteration of its other loops) reaches every later iteration of `L`. -/
def chain (ls : Loops) (f : Fact) (L : Nat) : Option Fact :=
  let lv := ls[f.src]?.getD []
  if f.src == f.dst && lv.contains L && f.pat.get L == .succ &&
      lv.all (fun L' => L' == L || f.pat.get L' == .eq) && f.pat.all (fun x => lv.contains x.1) then
    some { f with pat := normPat (f.pat.set L .lt) }
  else none

theorem chain_holds {ls : Loops} {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
    (htrans : ∀ a ia c ic b ib, R a ia c ic → R c ic b ib → R a ia b ib)
    {f h : Fact} {L : Nat} (hc : chain ls f L = some h) (hf : f.Holds ls n R) :
    h.Holds ls n R := by
  obtain ⟨a, b, π, g⟩ := f
  simp only [chain, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, Bool.or_eq_true] at hc
  split at hc
  case isFalse => cases hc
  case isTrue hcond =>
  cases hc
  obtain ⟨⟨⟨⟨hsd, hL⟩, hsucc⟩, hothers⟩, hkeys⟩ := hcond
  subst hsd
  have hinL : inL ls a L = true := by simpa [inL] using hL
  have heqO : ∀ L', L' ≠ L → inL ls a L' = true → π.get L' = .eq := by
    intro L' hne hin
    rcases hothers L' (by simpa [inL] using hin) with h | h
    · exact absurd h hne
    · exact h
  -- Loops outside the event's are `any`.
  have hout : ∀ L', inL ls a L' = false → π.get L' = .any := by
    intro L' hn
    apply Pat.get_of_not_mem
    intro hm
    obtain ⟨x, hx, rfl⟩ := List.mem_map.mp hm
    have := hkeys x hx
    simp only [inL] at hn
    simp_all
  -- `π` relates instances one iteration of `L` apart, equal in the others.
  have hstep : ∀ ia ib, ib L = ia L + 1 → Valid ls n a ia → Valid ls n a ib →
      (∀ L', L' ≠ L → inL ls a L' = true → ia L' = ib L') → GuardOk n g → R a ia a ib := by
    intro ia ib hd hva hvb heq hg
    refine hf hg ia ib hva hvb ?_
    intro L'
    by_cases hL' : L' = L
    · subst hL'; simp [hsucc, hinL, side, Rel.holds, hd]
    · cases hin : inL ls a L'
      · simp [hout L' hin, Rel.holds]
      · simp [heqO L' hL' hin, side, Rel.holds, heq L' hL' hin]
  intro hg ia ib hva hvb hm
  simp only at hva hvb hm ⊢
  have hmL := hm L
  rw [normPat_get, Pat.get_set] at hmL
  simp only [ite_true, hinL, side, Rel.holds, decide_eq_true_eq] at hmL
  have heq : ∀ L', L' ≠ L → inL ls a L' = true → ia L' = ib L' := by
    intro L' hne hin
    have := hm L'
    rw [normPat_get, Pat.get_set, ite_eq_right_iff.mpr (fun e => absurd e hne), heqO L' hne hin] at this
    simpa [hin, side, Rel.holds] using this
  -- Induction on the distance in `L`.
  suffices H : ∀ d ia, ib L = ia L + d + 1 → Valid ls n a ia →
      (∀ L', L' ≠ L → inL ls a L' = true → ia L' = ib L') → R a ia a ib from
    H (ib L - ia L - 1) ia (by omega) hva heq
  intro d
  induction d with
  | zero => intro ia hd hva heq; exact hstep ia ib (by omega) hva hvb heq hg
  | succ d ih =>
    intro ia hd hva heq
    let ic : Iter := fun L' => if L' = L then ia L + 1 else ia L'
    have hicO : ∀ L', L' ≠ L → ic L' = ia L' := fun L' h => by simp [ic, h]
    have hvc : Valid ls n a ic := by
      intro L' hin
      by_cases h : L' = L
      · subst h; have := hvb L' hin; simp [ic]; omega
      · rw [hicO L' h]; exact hva L' hin
    have r1 := hstep ia ic (by simp [ic]) hva hvc (fun L' h _ => (hicO L' h).symm) hg
    have r2 := ih ic (by simp [ic]; omega) hvc (fun L' h hin => by rw [hicO L' h]; exact heq L' h hin)
    exact htrans _ _ _ _ _ _ r1 r2

/-- Union: the same claim for `L` equal and for `L` later gives it for `L` equal or later. -/
def union (ls : Loops) (f g : Fact) (L : Nat) : Option Fact :=
  if f.src == g.src && f.dst == g.dst && f.guard == g.guard && f.pat.get L == .eq &&
      g.pat.get L == .lt &&
      (compKeys ls f g).all (fun L' => L' == L || f.pat.get L' == g.pat.get L') then
    some { f with pat := normPat (f.pat.set L .le) }
  else none

theorem union_holds {ls : Loops} {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
    {f g h : Fact} {L : Nat} (hc : union ls f g L = some h) (hf : f.Holds ls n R)
    (hg : g.Holds ls n R) : h.Holds ls n R := by
  simp only [union, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, Bool.or_eq_true] at hc
  split at hc
  case isFalse => cases hc
  case isTrue hcond =>
  cases hc
  obtain ⟨⟨⟨⟨⟨hs, hd⟩, hgd⟩, heqL⟩, hltL⟩, hsame⟩ := hcond
  -- The two patterns agree off `L`.
  have hag : ∀ L', L' ≠ L → f.pat.get L' = g.pat.get L' := by
    intro L' hne
    by_cases hk : L' ∈ compKeys ls f g
    · rcases hsame L' hk with h | h
      · exact absurd h hne
      · exact h
    · simp only [compKeys, List.mem_append, not_or] at hk
      rw [Pat.get_of_not_mem hk.1.2, Pat.get_of_not_mem hk.2]
  intro hguard ia ib hva hvb hm
  simp only at hguard hva hvb hm ⊢
  have hmL := hm L
  rw [normPat_get, Pat.get_set, ite_eq_left_iff.mpr (fun e => absurd rfl e)] at hmL
  cases ha : inL ls f.src L <;> cases hb : inL ls f.dst L <;>
    simp only [ha, hb, side, Rel.holds, ite_true, ite_false, Bool.false_eq_true,
      decide_eq_true_eq] at hmL
  rcases Nat.lt_or_eq_of_le hmL with hlt | heq
  · rw [hs, hd]
    refine hg (hgd ▸ hguard) ia ib (hs ▸ hva) (hd ▸ hvb) ?_
    intro L'
    rw [← hs, ← hd]
    by_cases h : L' = L
    · subst h; simp [hltL, ha, hb, side, Rel.holds, hlt]
    · have := hm L'
      rw [normPat_get, Pat.get_set, ite_eq_right_iff.mpr (fun e => absurd e h), hag L' h] at this
      exact this
  · refine hf hguard ia ib hva hvb ?_
    intro L'
    by_cases h : L' = L
    · subst h; simp [heqL, ha, hb, side, Rel.holds, heq]
    · have := hm L'
      rw [normPat_get, Pat.get_set, ite_eq_right_iff.mpr (fun e => absurd e h)] at this
      exact this

/-- Each instance reaches itself. -/
def reflFact (ls : Loops) (a : Nat) : Fact :=
  { src := a, dst := a, pat := (ls[a]?.getD []).map (·, .eq), guard := [] }

theorem reflFact_holds {ls : Loops} {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
    (hext : ∀ a ia ib, (∀ L, inL ls a L = true → ia L = ib L) → R a ia a ib) (a : Nat) :
    (reflFact ls a).Holds ls n R := by
  intro _ ia ib _ _ hm
  simp only [reflFact] at hm ⊢
  apply hext
  intro L hin
  have hL : L ∈ ls[a]?.getD [] := by simpa [inL] using hin
  have hget : Pat.get ((ls[a]?.getD []).map (·, Rel.eq)) L = .eq := by
    simp only [Pat.get, List.find?_map]
    cases hf : List.find? ((fun x => x.1 == L) ∘ fun L => (L, Rel.eq)) (ls[a]?.getD []) with
    | some x => rfl
    | none =>
      have := List.find?_eq_none.mp hf L hL
      simp at this
  have := hm L
  rw [hget, hin] at this
  simpa [side, Rel.holds] using this

/-! ### The closure -/

/-- Facts by source. -/
def bySrc (fs : List Fact) : Std.HashMap Nat (List Fact) :=
  fs.foldl (fun m f => m.insert f.src (f :: m.getD f.src [])) {}

theorem mem_bySrc {fs : List Fact} {k : Nat} {g : Fact} (h : g ∈ (bySrc fs).getD k []) :
    g ∈ fs := by
  suffices H : ∀ (l : List Fact) (m : Std.HashMap Nat (List Fact)),
      (∀ k, ∀ g ∈ m.getD k [], g ∈ fs) → (∀ g ∈ l, g ∈ fs) →
      ∀ k, ∀ g ∈ (l.foldl (fun m f => m.insert f.src (f :: m.getD f.src [])) m).getD k [], g ∈ fs from
    H fs {} (by simp) (fun _ h => h) k g h
  intro l
  induction l with
  | nil => intro m hm _ k g hg; exact hm k g hg
  | cons f l ih =>
    intro m hm hl
    apply ih
    · intro k g hg
      rw [Std.HashMap.getD_insert] at hg
      split at hg
      · rcases List.mem_cons.mp hg with h | h
        · subst h; exact hl _ (List.mem_cons_self ..)
        · exact hm _ g (by rename_i he; simp only [beq_iff_eq] at he; subst he; exact h)
      · exact hm k g hg
    · exact fun g hg => hl g (List.mem_cons_of_mem _ hg)

def nubStep (acc : List Fact × Std.HashSet Fact) (f : Fact) : List Fact × Std.HashSet Fact :=
  if acc.2.contains f then acc else (f :: acc.1, acc.2.insert f)

/-- `l` without repeats, keeping only elements of `l`. -/
def nubFacts (l : List Fact) : List Fact := (l.foldl nubStep ([], {})).1

theorem mem_nubFacts {l : List Fact} {f : Fact} (h : f ∈ nubFacts l) : f ∈ l := by
  have H : ∀ (l : List Fact) (acc : List Fact × Std.HashSet Fact) (g : Fact),
      g ∈ (l.foldl nubStep acc).1 → g ∈ acc.1 ∨ g ∈ l := by
    intro l
    induction l with
    | nil => intro acc g hg; exact Or.inl hg
    | cons x xs ih =>
      intro acc g hg
      simp only [List.foldl_cons] at hg
      rcases ih _ g hg with h | h
      · simp only [nubStep] at h
        split at h
        · exact Or.inl h
        · rcases List.mem_cons.mp h with h | h
          · subst h; exact Or.inr (List.mem_cons_self ..)
          · exact Or.inl h
      · exact Or.inr (List.mem_cons_of_mem _ h)
  rcases H l ([], {}) f h with h | h
  · simp at h
  · exact h

/-- Whether relation `r` holds of every pair `r'` holds of. -/
def relLe (r' r : Rel) : Bool :=
  r' == r || r == .any || (r == .le && (r' == .eq || r' == .lt || r' == .succ)) ||
    (r == .lt && r' == .succ)

/-- `f` claims what `g` claims: the same events, a guard of fewer conditions, a pattern at least as
general on every loop. Only used to leave `g` out. -/
def subsumes (f g : Fact) : Bool :=
  f.src == g.src && f.dst == g.dst && f.guard.all (g.guard.contains ·) &&
    ((f.pat.map (·.1)) ++ (g.pat.map (·.1))).all fun L => relLe (g.pat.get L) (f.pat.get L)

def pruneStep (acc : List Fact × Std.HashMap (Nat × Nat) (List Fact)) (g : Fact) :
    List Fact × Std.HashMap (Nat × Nat) (List Fact) :=
  let grp := acc.2.getD (g.src, g.dst) []
  if grp.any (subsumes · g) then acc else (g :: acc.1, acc.2.insert (g.src, g.dst) (g :: grp))

/-- The candidates that no fact of `all`, nor one kept before them, subsumes. -/
def prune (all cands : List Fact) : List Fact :=
  let init : Std.HashMap (Nat × Nat) (List Fact) :=
    all.foldl (fun m f => m.insert (f.src, f.dst) (f :: m.getD (f.src, f.dst) [])) {}
  (cands.foldl pruneStep ([], init)).1

theorem mem_prune {all cands : List Fact} {f : Fact} (h : f ∈ prune all cands) : f ∈ cands := by
  have H : ∀ (l : List Fact) (acc : List Fact × Std.HashMap (Nat × Nat) (List Fact)) (g : Fact),
      g ∈ (l.foldl pruneStep acc).1 → g ∈ acc.1 ∨ g ∈ l := by
    intro l
    induction l with
    | nil => intro acc g hg; exact Or.inl hg
    | cons x xs ih =>
      intro acc g hg
      simp only [List.foldl_cons] at hg
      rcases ih _ g hg with h | h
      · simp only [pruneStep] at h
        split at h
        · exact Or.inl h
        · rcases List.mem_cons.mp h with h | h
          · subst h; exact Or.inr (List.mem_cons_self ..)
          · exact Or.inl h
      · exact Or.inr (List.mem_cons_of_mem _ h)
  rcases H cands _ f h with h | h
  · simp at h
  · exact h

/-- What composition, the chain rule and union derive using at least one fact of `delta`. -/
def derive (ls : Loops) (all delta : List Fact) : List Fact :=
  let mAll := bySrc all
  let mDelta := bySrc delta
  (delta.flatMap fun f => (mAll.getD f.dst []).filterMap (compose ls f)) ++
  (all.flatMap fun f => (mDelta.getD f.dst []).filterMap (compose ls f)) ++
  (delta.flatMap fun f => (ls[f.src]?.getD []).filterMap (chain ls f)) ++
  (delta.flatMap fun f =>
    (mAll.getD f.src []).flatMap fun g => (f.pat.map (·.1)).filterMap (union ls f g)) ++
  (all.flatMap fun f =>
    (mDelta.getD f.src []).flatMap fun g => (f.pat.map (·.1)).filterMap (union ls f g))

/-- Rounds until nothing new, at most `fuel`; each round derives only from the last round's facts. -/
def closeSN (ls : Loops) : Nat → List Fact → List Fact → List Fact
  | 0, all, _ => all
  | k + 1, all, delta =>
    if delta.isEmpty then all else
    let new := prune all (derive ls all delta)
    closeSN ls k (all ++ new) new

section
variable {ls : Loops} {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
  (htrans : ∀ a ia c ic b ib, R a ia c ic → R c ic b ib → R a ia b ib)
include htrans

theorem derive_holds {all delta : List Fact} (ha : ∀ f ∈ all, f.Holds ls n R)
    (hd : ∀ f ∈ delta, f.Holds ls n R) : ∀ f ∈ derive ls all delta, f.Holds ls n R := by
  intro f hf
  simp only [derive, List.mem_append, List.mem_flatMap, List.mem_filterMap] at hf
  rcases hf with ((((⟨a, ha', b, hb, hc⟩ | ⟨a, ha', b, hb, hc⟩) | ⟨a, ha', L, _, hc⟩) |
    ⟨a, ha', b, hb, L, _, hc⟩) | ⟨a, ha', b, hb, L, _, hc⟩)
  · exact compose_holds htrans hc (hd a ha') (ha b (mem_bySrc hb))
  · exact compose_holds htrans hc (ha a ha') (hd b (mem_bySrc hb))
  · exact chain_holds htrans hc (hd a ha')
  · exact union_holds hc (hd a ha') (ha b (mem_bySrc hb))
  · exact union_holds hc (ha a ha') (hd b (mem_bySrc hb))

theorem closeSN_holds {k : Nat} {all delta : List Fact} (ha : ∀ f ∈ all, f.Holds ls n R)
    (hd : ∀ f ∈ delta, f.Holds ls n R) : ∀ f ∈ closeSN ls k all delta, f.Holds ls n R := by
  induction k generalizing all delta with
  | zero => exact ha
  | succ k ih =>
    simp only [closeSN]
    split
    · exact ha
    · have hn : ∀ f ∈ prune all (derive ls all delta), f.Holds ls n R :=
        fun f hf => derive_holds htrans ha hd f (mem_prune hf)
      exact ih (fun f hf => (List.mem_append.mp hf).elim (ha f) (hn f)) hn

end

/-- Facts by source and target. -/
def byPair (fs : List Fact) : Std.HashMap (Nat × Nat) (List Fact) :=
  fs.foldl (fun m f => m.insert (f.src, f.dst) (f :: m.getD (f.src, f.dst) [])) {}

theorem mem_byPair {fs : List Fact} {k : Nat × Nat} {g : Fact} (h : g ∈ (byPair fs).getD k []) :
    g ∈ fs := by
  suffices H : ∀ (l : List Fact) (m : Std.HashMap (Nat × Nat) (List Fact)),
      (∀ k, ∀ g ∈ m.getD k [], g ∈ fs) → (∀ g ∈ l, g ∈ fs) →
      ∀ k, ∀ g ∈ (l.foldl (fun m f => m.insert (f.src, f.dst) (f :: m.getD (f.src, f.dst) [])) m).getD k [],
        g ∈ fs from
    H fs {} (by simp) (fun _ h => h) k g h
  intro l
  induction l with
  | nil => intro m hm _ k g hg; exact hm k g hg
  | cons f l ih =>
    intro m hm hl
    apply ih
    · intro k g hg
      rw [Std.HashMap.getD_insert] at hg
      split at hg
      · rcases List.mem_cons.mp hg with h | h
        · subst h; exact hl _ (List.mem_cons_self ..)
        · exact hm _ g (by rename_i he; simp only [beq_iff_eq] at he; subst he; exact h)
      · exact hm k g hg
    · exact fun g hg => hl g (List.mem_cons_of_mem _ hg)

/-! ### Footprints -/

/-- An access of a template event: a buffer, whether it writes, and the positions
`base + Σ_L coef L * it L + q` for `q ∈ offs`. -/
structure TAcc where
  buf : Nat
  write : Bool
  base : Int
  coef : List (Nat × Int)
  offs : Array Int
deriving Repr, Inhabited

def coefOf (a : TAcc) (L : Nat) : Int := ((a.coef.find? (·.1 == L)).map (·.2)).getD 0

/-- The position of offset `q` of access `a` in the instance with iterations `it`; `nl` is the
number of loops of the template. -/
def TAcc.pos (a : TAcc) (nl : Nat) (it : Iter) (q : Int) : Int :=
  a.base + ((List.range nl).map fun L => coefOf a L * (it L : Int)).sum + q

theorem sum_map_sub (l : List Nat) (f g : Nat → Int) :
    (l.map f).sum - (l.map g).sum = (l.map fun L => f L - g L).sum := by
  induction l with
  | nil => simp
  | cons x xs ih => simp only [List.map_cons, List.sum_cons]; omega

/-- Two positions are equal iff the offsets differ by the difference of the shifts. -/
theorem pos_eq_iff {a b : TAcc} {nl : Nat} {ia ib : Iter} {q q' : Int} :
    a.pos nl ia q = b.pos nl ib q' ↔
      q - q' = (b.base - a.base) +
        ((List.range nl).map fun L => coefOf b L * (ib L : Int) - coefOf a L * (ia L : Int)).sum := by
  simp only [TAcc.pos]
  rw [← sum_map_sub]
  omega

/-- A set of integers: a finite list, or the multiples `c * k` for `k ≥ kmin`. -/
inductive CSet where
  | fin (xs : List Int)
  | prog (c : Int) (kmin : Nat)
deriving Repr, Inhabited

def CSet.Mem : CSet → Int → Prop
  | .fin xs, x => x ∈ xs
  | .prog c kmin, x => ∃ k : Nat, kmin ≤ k ∧ x = c * k

/-- Sorted, without adjacent repeats. -/
def dedupSorted : List Int → List Int
  | a :: b :: t => if a = b then dedupSorted (b :: t) else a :: dedupSorted (b :: t)
  | l => l

theorem mem_dedupSorted {x : Int} : ∀ {l : List Int}, x ∈ dedupSorted l ↔ x ∈ l
  | [] => by simp [dedupSorted]
  | [a] => by simp [dedupSorted]
  | a :: b :: t => by
    have ih := @mem_dedupSorted x (b :: t)
    unfold dedupSorted
    split
    · rename_i h; subst h; rw [ih]; simp
    · rw [List.mem_cons, ih]; simp

/-- Every sum of an element of `xs` and one of `ys`. -/
def sumFin (xs ys : List Int) : List Int :=
  dedupSorted ((xs.flatMap fun x => ys.map (x + ·)).mergeSort (· ≤ ·))

theorem mem_sumFin {xs ys : List Int} {x y : Int} (hx : x ∈ xs) (hy : y ∈ ys) :
    x + y ∈ sumFin xs ys := by
  simp only [sumFin, mem_dedupSorted, List.mem_mergeSort, List.mem_flatMap, List.mem_map]
  exact ⟨x, hx, y, hy, rfl⟩

/-- How the iterations of the two instances compare on the loops around both. -/
abbrev Region := List (Nat × Ordering)

def ordOf (σ : Region) (L : Nat) : Ordering := ((σ.find? (·.1 == L)).map (·.2)).getD .eq

def InRegion (ls : Loops) (v w : Nat) (σ : Region) (iv iw : Iter) : Prop :=
  ∀ L, inL ls v L = true → inL ls w L = true → compare (iv L) (iw L) = ordOf σ L

/-- Known trip counts. -/
abbrev Bounds := List (Nat × Nat)

def boundOf (known : Bounds) (L : Nat) : Option Nat := ((known.find? (·.1 == L)).map (·.2))

def BoundsOk (known : Bounds) (n : Nat → Nat) : Prop := ∀ L N, boundOf known L = some N → n L = N

/-- The iteration pairs a loop of `N` iterations allows (`0` for an end outside it). -/
def pairsOf (N : Nat) (inV inW : Bool) (o : Ordering) : List (Nat × Nat) :=
  if inV && inW then
    (List.range N).flatMap fun i => ((List.range N).filter fun j => compare i j == o).map (i, ·)
  else if inV then (List.range N).map (·, 0)
  else (List.range N).map (0, ·)

/-- What loop `L` adds to the difference of the two positions' shifts. -/
def contrib (ls : Loops) (known : Bounds) (v w : Nat) (σ : Region) (a b : TAcc) (L : Nat) :
    Option CSet :=
  let ca := coefOf a L
  let cb := coefOf b L
  let inV := inL ls v L
  let inW := inL ls w L
  if ca == 0 && cb == 0 then some (.fin [0])
  else if (ca != 0 && !inV) || (cb != 0 && !inW) then none
  else match boundOf known L with
  | some N => some (.fin ((pairsOf N inV inW (ordOf σ L)).map fun (i, j) => cb * j - ca * i))
  | none =>
    if inV && inW then
      match ordOf σ L with
      | .eq => if ca == cb then some (.fin [0]) else some (.prog (cb - ca) 0)
      | .lt => if ca == cb then some (.prog ca 1) else none
      | .gt => if ca == cb then some (.prog (-ca) 1) else none
    else if inV then some (.prog (-ca) 0)
    else some (.prog cb 0)

theorem contrib_mem {ls : Loops} {known : Bounds} {n : Nat → Nat} {v w : Nat} {σ : Region}
    {a b : TAcc} {L : Nat} {cs : CSet} (h : contrib ls known v w σ a b L = some cs)
    (hb : BoundsOk known n) {iv iw : Iter} (hv : Valid ls n v iv) (hw : Valid ls n w iw)
    (hr : InRegion ls v w σ iv iw) :
    cs.Mem (coefOf b L * (iw L : Int) - coefOf a L * (iv L : Int)) := by
  simp only [contrib] at h
  split at h
  · rename_i h0
    simp only [Bool.and_eq_true, beq_iff_eq] at h0
    cases h; simp [CSet.Mem, h0.1, h0.2]
  rename_i h0
  split at h
  · cases h
  rename_i h1
  simp only [Bool.or_eq_true, Bool.and_eq_true, bne_iff_ne, ne_eq, Bool.not_eq_true',
    not_or, not_and, Bool.not_eq_false] at h1
  obtain ⟨h1a, h1b⟩ := h1
  have hcaV : inL ls v L = false → coefOf a L = 0 := fun hn =>
    Classical.byContradiction fun hc => by rw [h1a hc] at hn; cases hn
  have hcbW : inL ls w L = false → coefOf b L = 0 := fun hn =>
    Classical.byContradiction fun hc => by rw [h1b hc] at hn; cases hn
  split at h
  · -- A known bound: the pair is enumerated.
    rename_i N hN
    have hnL := hb L N hN
    cases h
    simp only [CSet.Mem, List.mem_map, Prod.exists]
    cases hV : inL ls v L <;> cases hW : inL ls w L
    · simp only [Bool.and_eq_true, beq_iff_eq, not_and] at h0
      exact absurd (hcbW hW) (h0 (hcaV hV))
    · refine ⟨0, iw L, ?_, ?_⟩
      · simp [pairsOf, hV]; have := hw L hW; omega
      · rw [hcaV hV]; simp
    · refine ⟨iv L, 0, ?_, ?_⟩
      · simp [pairsOf, hV]; have := hv L hV; omega
      · rw [hcbW hW]; simp
    · refine ⟨iv L, iw L, ?_, rfl⟩
      have := hv L hV; have := hw L hW
      simp only [pairsOf, hV, hW, Bool.and_self, ite_true, List.mem_flatMap, List.mem_range,
        List.mem_map, List.mem_filter, beq_iff_eq, Prod.mk.injEq]
      exact ⟨iv L, by omega, iw L, ⟨by omega, hr L hV hW⟩, rfl, rfl⟩
  · -- An unknown bound.
    cases hV : inL ls v L <;> cases hW : inL ls w L <;> simp only [hV, hW, Bool.and_self,
      Bool.and_false, Bool.false_and, ite_true, ite_false, Bool.false_eq_true] at h
    · simp only [Bool.not_eq_true, Bool.and_eq_true, beq_iff_eq, not_and] at h0
      exact absurd (hcbW hW) (h0 (hcaV hV))
    · cases h; rw [hcaV hV]; exact ⟨iw L, Nat.zero_le _, by simp⟩
    · cases h; rw [hcbW hW]; exact ⟨iv L, Nat.zero_le _, by simp [Int.neg_mul]⟩
    · have hcmp := hr L hV hW
      split at h
      · rename_i ho
        rw [ho] at hcmp
        have he : iv L = iw L := Nat.compare_eq_eq.mp hcmp
        split at h
        · rename_i hab; simp only [beq_iff_eq] at hab
          cases h; simp [CSet.Mem, he, hab]
        · cases h; exact ⟨iv L, Nat.zero_le _, by rw [he, Int.sub_mul]⟩
      · rename_i ho
        rw [ho] at hcmp
        have hl : iv L < iw L := Nat.compare_eq_lt.mp hcmp
        split at h
        · rename_i hab; simp only [beq_iff_eq] at hab
          cases h
          refine ⟨iw L - iv L, by omega, ?_⟩
          rw [hab, Int.natCast_sub (by omega), Int.mul_sub]
        · cases h
      · rename_i ho
        rw [ho] at hcmp
        have hl : iw L < iv L := Nat.compare_eq_gt.mp hcmp
        split at h
        · rename_i hab; simp only [beq_iff_eq] at hab
          cases h
          refine ⟨iv L - iw L, by omega, ?_⟩
          rw [hab, Int.natCast_sub (by omega), Int.neg_mul, Int.mul_sub, Int.neg_sub]
        · cases h

/-- The sums of one contribution per loop of `Ls`: the finite contributions summed, the
progressions listed. -/
def sumContribs (f : Nat → Option CSet) (cap : Nat) : List Nat → Option (List Int × List (Int × Nat))
  | [] => some ([0], [])
  | L :: Ls => do
    let (F, P) ← sumContribs f cap Ls
    match ← f L with
    | .fin xs => if F.length * xs.length > cap then none else some (sumFin xs F, P)
    | .prog c k => some (F, (c, k) :: P)

/-- Each sum of contributions is a finite sum plus multiples of the progressions. -/
theorem sumContribs_mem {f : Nat → Option CSet} {cap : Nat} {t : Nat → Int} :
    ∀ {Ls : List Nat} {F : List Int} {P : List (Int × Nat)},
    sumContribs f cap Ls = some (F, P) → (∀ L ∈ Ls, ∀ cs, f L = some cs → cs.Mem (t L)) →
    ∃ s ∈ F, ∃ ks : List Nat, ks.length = P.length ∧
      (∀ i (hi : i < P.length) (hk : i < ks.length), P[i].2 ≤ ks[i]) ∧
      (Ls.map t).sum = s + ((P.zip ks).map fun x => x.1.1 * (x.2 : Int)).sum
  | [], F, P, h, _ => by
    simp only [sumContribs, Option.some.injEq, Prod.mk.injEq] at h
    obtain ⟨rfl, rfl⟩ := h
    exact ⟨0, by simp, [], rfl, by simp, by simp⟩
  | L :: Ls, F, P, h, hm => by
    simp only [sumContribs, Option.bind_eq_bind] at h
    cases hr : sumContribs f cap Ls with
    | none => simp [hr] at h
    | some r =>
      obtain ⟨F', P'⟩ := r
      obtain ⟨s, hs, ks, hl, hk, hsum⟩ :=
        sumContribs_mem hr (fun L' hL' => hm L' (List.mem_cons_of_mem _ hL'))
      simp only [hr, Option.bind_some] at h
      cases hf : f L with
      | none => simp [hf] at h
      | some cs =>
        have hmem := hm L (List.mem_cons_self ..) cs hf
        simp only [hf, Option.bind_some] at h
        cases cs with
        | fin xs =>
          simp only at h
          split at h
          · cases h
          · simp only [Option.some.injEq, Prod.mk.injEq] at h
            obtain ⟨rfl, rfl⟩ := h
            refine ⟨t L + s, mem_sumFin hmem hs, ks, hl, hk, ?_⟩
            simp only [List.map_cons, List.sum_cons, hsum]; omega
        | prog c km =>
          simp only [Option.some.injEq, Prod.mk.injEq] at h
          obtain ⟨rfl, rfl⟩ := h
          obtain ⟨k, hkm, hkv⟩ := hmem
          refine ⟨s, hs, k :: ks, by simp [hl], ?_, ?_⟩
          · intro i hi hk'
            cases i with
            | zero => simpa using hkm
            | succ i => simpa using hk i (by simpa using hi) (by simpa using hk')
          · simp only [List.map_cons, List.sum_cons, hsum, List.zip_cons_cons, hkv]; omega

/-- Whether some offset of `a` minus some offset of `b` is `δ`. -/
def hitAny (aoffs : Array Int) (bset : Std.HashSet Int) (δ : Int) : Bool :=
  aoffs.any fun q => bset.contains (q - δ)

theorem hitAny_of {aoffs boffs : Array Int} {q q' δ : Int} (hq : q ∈ aoffs) (hq' : q' ∈ boffs)
    (h : q - q' = δ) : hitAny aoffs (Std.HashSet.ofList boffs.toList) δ = true := by
  simp only [hitAny, Array.any_eq_true]
  obtain ⟨i, hi, rfl⟩ := Array.mem_iff_getElem.mp hq
  refine ⟨i, hi, ?_⟩
  rw [Std.HashSet.contains_ofList, List.contains_iff_mem, Array.mem_toList_iff]
  have : aoffs[i] - δ = q' := by omega
  rw [this]; exact hq'

theorem mul_le_mul_nat {c : Int} (hc : 0 ≤ c) {k k' : Nat} (h : k ≤ k') : c * k ≤ c * k' :=
  Int.mul_le_mul_of_nonneg_left (by omega) hc

/-- From `k` on, values `start + c * k` (`c > 0`, increasing) do not hit until they pass `dmax`. -/
def scanUp (hit : Int → Bool) (start c dmax : Int) : Nat → Nat → Bool
  | 0, _ => false
  | fuel + 1, k =>
    if start + c * k > dmax then true else !hit (start + c * k) && scanUp hit start c dmax fuel (k + 1)

theorem scanUp_ok {hit : Int → Bool} {start c dmax : Int} (hc : 0 < c) :
    ∀ {fuel k : Nat}, scanUp hit start c dmax fuel k = true →
      ∀ k', k ≤ k' → start + c * k' ≤ dmax → hit (start + c * k') = false
  | 0, _, h => by simp [scanUp] at h
  | fuel + 1, k, h => by
    intro k' hk hle
    simp only [scanUp] at h
    split at h
    · have := mul_le_mul_nat (Int.le_of_lt hc) hk; omega
    · simp only [Bool.and_eq_true, Bool.not_eq_true'] at h
      rcases Nat.lt_or_eq_of_le hk with hlt | heq
      · exact scanUp_ok hc h.2 k' hlt hle
      · subst heq; exact h.1

/-- The same, decreasing (`c < 0`) until below `dmin`. -/
def scanDown (hit : Int → Bool) (start c dmin : Int) : Nat → Nat → Bool
  | 0, _ => false
  | fuel + 1, k =>
    if start + c * k < dmin then true else !hit (start + c * k) && scanDown hit start c dmin fuel (k + 1)

theorem scanDown_ok {hit : Int → Bool} {start c dmin : Int} (hc : c < 0) :
    ∀ {fuel k : Nat}, scanDown hit start c dmin fuel k = true →
      ∀ k', k ≤ k' → dmin ≤ start + c * k' → hit (start + c * k') = false
  | 0, _, h => by simp [scanDown] at h
  | fuel + 1, k, h => by
    intro k' hk hle
    simp only [scanDown] at h
    split at h
    · have := mul_le_mul_nat (c := -c) (by omega) hk
      simp only [Int.neg_mul] at this; omega
    · simp only [Bool.and_eq_true, Bool.not_eq_true'] at h
      rcases Nat.lt_or_eq_of_le hk with hlt | heq
      · exact scanDown_ok hc h.2 k' hlt hle
      · subst heq; exact h.1

/-- How many values one progression may be scanned for. -/
def scanFuel : Nat := 1000000

/-- No `start + c * k` (`k ≥ kmin`) in `[dmin, dmax]` hits. Skips ahead to the range, checking
that what is skipped lies outside it. -/
def progOk (hit : Int → Bool) (start c : Int) (kmin : Nat) (dmin dmax : Int) : Bool :=
  if 0 < c then
    let k0 := max kmin (if start ≥ dmin then 0 else ((dmin - start + c - 1) / c).toNat)
    (k0 == kmin || start + c * (k0 - 1 : Nat) < dmin) && scanUp hit start c dmax scanFuel k0
  else if c < 0 then
    let k0 := max kmin (if start ≤ dmax then 0 else ((start - dmax + (-c) - 1) / (-c)).toNat)
    (k0 == kmin || start + c * (k0 - 1 : Nat) > dmax) && scanDown hit start c dmin scanFuel k0
  else false

theorem progOk_ok {hit : Int → Bool} {start c : Int} {kmin : Nat} {dmin dmax : Int}
    (h : progOk hit start c kmin dmin dmax = true) {k : Nat} (hk : kmin ≤ k)
    (hlo : dmin ≤ start + c * k) (hhi : start + c * k ≤ dmax) : hit (start + c * k) = false := by
  simp only [progOk] at h
  split at h
  · rename_i hc
    simp only [Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq, decide_eq_true_eq] at h
    obtain ⟨hskip, hscan⟩ := h
    generalize hk0 : max kmin _ = k0 at hskip hscan
    by_cases hkk : k0 ≤ k
    · exact scanUp_ok hc hscan k hkk hhi
    · rcases hskip with h | h
      · omega
      · have := mul_le_mul_nat (Int.le_of_lt hc) (show k ≤ k0 - 1 by omega); omega
  · split at h
    · rename_i _ hc
      simp only [Bool.and_eq_true, Bool.or_eq_true, beq_iff_eq, decide_eq_true_eq] at h
      obtain ⟨hskip, hscan⟩ := h
      generalize hk0 : max kmin _ = k0 at hskip hscan
      by_cases hkk : k0 ≤ k
      · exact scanDown_ok hc hscan k hkk hlo
      · rcases hskip with h | h
        · omega
        · have := mul_le_mul_nat (c := -c) (by omega) (show k ≤ k0 - 1 by omega)
          simp only [Int.neg_mul] at this; omega
    · cases h

/-- A lower and an upper bound of the elements, checked. -/
def lo (xs : Array Int) : Int := xs.foldl min (xs[0]?.getD 0)
def hi (xs : Array Int) : Int := xs.foldl max (xs[0]?.getD 0)

/-- The equation `q - q' = (b.base - a.base) + Σ_L contribution` has no solution with the
iterations in region `σ`. -/
def disjointOk (nl : Nat) (ls : Loops) (known : Bounds) (v w : Nat) (σ : Region) (a b : TAcc) :
    Bool :=
  match sumContribs (contrib ls known v w σ a b) 100000 (List.range nl) with
  | none => false
  | some (F, P) =>
    let base := b.base - a.base
    let bset := Std.HashSet.ofList b.offs.toList
    let hit := hitAny a.offs bset
    let dmin := lo a.offs - hi b.offs
    let dmax := hi a.offs - lo b.offs
    a.offs.all (fun q => lo a.offs ≤ q && q ≤ hi a.offs) &&
    b.offs.all (fun q => lo b.offs ≤ q && q ≤ hi b.offs) &&
    match P with
    | [] => F.all fun s => !hit (base + s)
    | [(c, kmin)] => F.all fun s => progOk hit (base + s) c kmin dmin dmax
    | _ => false

theorem disjointOk_sound {nl : Nat} {ls : Loops} {known : Bounds} {v w : Nat} {σ : Region}
    {a b : TAcc} (h : disjointOk nl ls known v w σ a b = true) {n : Nat → Nat}
    (hb : BoundsOk known n) {iv iw : Iter} (hv : Valid ls n v iv) (hw : Valid ls n w iw)
    (hr : InRegion ls v w σ iv iw) {q q' : Int} (hq : q ∈ a.offs) (hq' : q' ∈ b.offs) :
    a.pos nl iv q ≠ b.pos nl iw q' := by
  intro heq
  rw [pos_eq_iff] at heq
  simp only [disjointOk] at h
  split at h
  · cases h
  rename_i F P hs
  obtain ⟨s, hsF, ks, hkl, hkm, hsum⟩ := sumContribs_mem (t := fun L => coefOf b L * (iw L : Int) -
    coefOf a L * (iv L : Int)) hs (fun L _ cs hc => contrib_mem hc hb hv hw hr)
  simp only [Bool.and_eq_true, Array.all_eq_true', decide_eq_true_eq] at h
  obtain ⟨⟨hab, hbb⟩, hrest⟩ := h
  have hhit := hitAny_of (boffs := b.offs) hq hq' rfl
  have hqa := hab q hq
  have hqb := hbb q' hq'
  split at hrest
  · simp only [List.length_nil] at hkl
    cases ks with
    | cons _ _ => simp at hkl
    | nil =>
      simp only [List.zip_nil_right, List.map_nil, List.sum_nil, Int.add_zero] at hsum
      have := List.all_eq_true.mp hrest s hsF
      rw [← hsum, ← heq] at this
      simp [hhit] at this
  · rename_i c kmin
    cases ks with
    | nil => simp at hkl
    | cons k ks' =>
      cases ks' with
      | cons _ _ => simp at hkl
      | nil =>
        have hk := hkm 0 (by simp) (by simp)
        simp only [List.getElem_cons_zero] at hk
        simp only [List.zip_cons_cons, List.zip_nil_right, List.map_cons, List.map_nil,
          List.sum_cons, List.sum_nil, Int.add_zero] at hsum
        have := progOk_ok (List.all_eq_true.mp hrest s hsF) hk (by omega) (by omega)
        rw [show b.base - a.base + s + c * k = q - q' by omega] at this
        simp [hhit] at this
  · cases hrest

/-! ### The certificate -/

/-- A template: loops `0, …, nl - 1`; per event its loops, its footprint; per buffer the loops
that allocate it anew in each iteration; the edges, as facts. -/
structure Template where
  nl : Nat
  loops : Loops
  known : Bounds
  bufLoops : Array (List Nat)
  fps : Array (List TAcc)
  edges : List Fact
  fuel : Nat := 32
deriving Inhabited

/-- Every way the loops `C` can compare. -/
def regions : List Nat → List Region
  | [] => [[]]
  | L :: C => [Ordering.lt, .eq, .gt].flatMap fun o => (regions C).map ((L, o) :: ·)

theorem mem_regions (iv iw : Iter) : ∀ C : List Nat,
    (C.map fun L => (L, compare (iv L) (iw L))) ∈ regions C
  | [] => by simp [regions]
  | L :: C => by
    simp only [regions, List.map_cons, List.mem_flatMap, List.mem_cons, List.mem_map,
      List.not_mem_nil, or_false]
    refine ⟨compare (iv L) (iw L), ?_, _, mem_regions iv iw C, rfl⟩
    cases compare (iv L) (iw L) <;> simp

theorem ordOf_map {iv iw : Iter} {C : List Nat} {L : Nat} (h : L ∈ C) :
    ordOf (C.map fun L => (L, compare (iv L) (iw L))) L = compare (iv L) (iw L) := by
  simp only [ordOf, List.find?_map]
  cases hf : List.find? ((fun x => x.1 == L) ∘ fun L => (L, compare (iv L) (iw L))) C with
  | some x =>
    have := List.find?_some hf
    simp only [Function.comp, beq_iff_eq] at this
    subst this; rfl
  | none =>
    have := List.find?_eq_none.mp hf L h
    simp at this

/-- Whether relation `r` of a fact covers iterations comparing as `o`: forward (source `v`), or
backward (source `w`). -/
def allowed (fwd : Bool) (o : Ordering) (r : Rel) : Bool :=
  r == .any || match fwd, o with
    | _, .eq => r == .eq || r == .le
    | true, .lt => r == .lt || r == .le
    | false, .gt => r == .lt || r == .le
    | _, _ => false

/-- Fact `f` orders the instances of `v` and `w` in region `σ`, one way or the other. -/
def covers (ls : Loops) (v w : Nat) (σ : Region) (fwd : Bool) (f : Fact) : Bool :=
  f.src == (if fwd then v else w) && f.dst == (if fwd then w else v) &&
    f.pat.all fun x => x.2 == .any || (inL ls v x.1 && inL ls w x.1 && allowed fwd (ordOf σ x.1) x.2)

/-- Every guard entry holds: a loop around `v` or `w` has iterations, or `ρ` gives its emptiness. -/
def guardFits (ls : Loops) (v w : Nat) (ρ : List (Nat × Bool)) (g : Guard) : Bool :=
  g.all fun x => ((inL ls v x.1 || inL ls w x.1) && x.2 == false) || ρ.lookup x.1 == some x.2

/-- Every emptiness of the loops `G`. -/
def assigns : List Nat → List (List (Nat × Bool))
  | [] => [[]]
  | L :: G => [true, false].flatMap fun z => (assigns G).map ((L, z) :: ·)

theorem mem_assigns (n : Nat → Nat) : ∀ G : List Nat, (G.map fun L => (L, n L == 0)) ∈ assigns G
  | [] => by simp [assigns]
  | L :: G => by
    simp only [assigns, List.map_cons, List.mem_flatMap, List.mem_cons, List.mem_map,
      List.not_mem_nil, or_false]
    exact ⟨n L == 0, by cases n L == 0 <;> simp, _, mem_assigns n G, rfl⟩

/-- For every emptiness of the loops the candidate facts' guards mention, some candidate fits. -/
def orderedOk (ls : Loops) (facts : List Fact) (v w : Nat) (σ : Region) : Bool :=
  let cands := facts.filter fun f => covers ls v w σ true f || covers ls v w σ false f
  let G := ((cands.flatMap (·.guard)).map (·.1)).eraseDups
  G.length ≤ 10 && (assigns G).all fun ρ => cands.any fun f => guardFits ls v w ρ f.guard

/-- Each pair of accesses of two events is ordered or disjoint in every region, or the two are
one instance. -/
def pairOk (T : Template) (facts : Nat → Nat → List Fact) (v w : Nat) (a b : TAcc) : Bool :=
  !(a.buf == b.buf && (a.write || b.write)) ||
    let C := (T.loops[v]?.getD []).filter (inL T.loops w)
    (regions C).all fun σ =>
      (v == w && σ.all (·.2 == .eq)) ||
      (T.bufLoops[a.buf]?.getD []).any (fun L => inL T.loops v L && inL T.loops w L &&
        ordOf σ L != .eq) ||
      orderedOk T.loops (facts v w ++ facts w v) v w σ ||
      disjointOk T.nl T.loops T.known v w σ a b

def Template.facts (T : Template) : List Fact :=
  let init := prune [] (T.edges ++ (List.range T.loops.size).map (reflFact T.loops))
  closeSN T.loops T.fuel init init

/-- **The certificate**: every pair of accesses of every pair of events passes `pairOk`. -/
def Template.certOk (T : Template) : Bool :=
  let m := byPair T.facts
  let facts (v w : Nat) := m.getD (v, w) []
  (List.range T.loops.size).all fun v => (List.range T.loops.size).all fun w =>
    (T.fps[v]?.getD []).all fun a => (T.fps[w]?.getD []).all fun b => pairOk T facts v w a b

/-! ### The theorem -/

open Chan in
/-- A channel program `p` with footprints `fp` is what template `T` stands for, for trip counts
`n`: `num` numbers instances as events of `p`, and `loc` places a position of a buffer instance in
`p`'s memory (a buffer and an element). -/
structure Realizes (T : Template) (n : Nat → Nat) (p : Prog) (fp : LFp) (num : Nat → Iter → Nat)
    (loc : Nat → Iter → Int → Nat × Int) (exempt : Nat → Prop) (S : Chan.Label → Prop) : Prop where
  bounds : BoundsOk T.known n
  /-- Each edge of the template is a dependency of `p`. -/
  edges : ∀ f ∈ T.edges, f.Holds T.loops n fun a ia b ib => DepGraph.Reach p.graph (num a ia) (num b ib)
  /-- An instance is its iterations of its own loops. -/
  ext : ∀ a ia ib, (∀ L, inL T.loops a L = true → ia L = ib L) → num a ia = num a ib
  /-- One place in memory is one position of one buffer instance (a buffer allocated in each
  iteration of a loop is a new buffer in each). -/
  loc_inj : ∀ b it q b' it' q', loc b it q = loc b' it' q' →
    b = b' ∧ (∀ L ∈ T.bufLoops[b]?.getD [], it L = it' L) ∧ q = q'
  /-- Conflicts on the buffers `exempt` holds of are ordered by the stream itself (a stream
  element's slot: written by its read, read by its arrival). -/
  exempt_ordered : ∀ x y a b, S x → S y → x ≠ y → a ∈ fp x → b ∈ fp y → a.Conflicts b →
    exempt a.buf → HB p x y ∨ HB p y x
  /-- Each other access of a label lies in an access of an instance that starts before it and
  finishes after it. -/
  cover : ∀ x, S x → ∀ acc ∈ fp x, ¬ exempt acc.buf → ∃ v it, v < T.loops.size ∧ Valid T.loops n v it ∧
    num v it ∈ finishersL p x ∧ num v it ∈ startersL p x ∧
    ∃ ta ∈ T.fps[v]?.getD [], (acc.kind = .write → ta.write = true) ∧
      ∀ e ∈ acc.elems, ∃ q ∈ ta.offs, (acc.buf, e) = loc ta.buf it (ta.pos T.nl it q)
  /-- Two labels one event both starts before and finishes after are ordered when they conflict
  (the stream's order). -/
  self : ∀ x y u, S x → S y → x ≠ y → LConflict fp x y → u ∈ finishersL p x → u ∈ startersL p x →
    u ∈ finishersL p y → u ∈ startersL p y → HB p x y ∨ HB p y x

theorem lookup_map_eq {G : List Nat} {g : Nat → Bool} {k : Nat} {z : Bool}
    (h : (G.map fun L => (L, g L)).lookup k = some z) : g k = z := by
  induction G with
  | nil => simp at h
  | cons L G ih =>
    simp only [List.map_cons, List.lookup_cons] at h
    split at h
    · rename_i he; simp only [beq_iff_eq] at he; subst he; simpa using h
    · exact ih h

/-- A relation `allowed` keeps holds of iterations comparing as `o`. -/
theorem allowed_holds {fwd : Bool} {o : Ordering} {r : Rel} (h : allowed fwd o r = true)
    {N i j : Nat} (ho : compare i j = o) :
    r.holds N (some (if fwd then i else j)) (some (if fwd then j else i)) = true := by
  simp only [allowed, Bool.or_eq_true, beq_iff_eq] at h
  rcases h with h | h
  · subst h; rfl
  · cases fwd <;> cases o <;> simp only [Bool.false_eq_true, Bool.or_eq_true, beq_iff_eq] at h <;>
      first
        | (rcases h with h | h <;> subst h <;> simp [Rel.holds] <;>
            first | exact Nat.compare_eq_eq.mp ho | exact (Nat.compare_eq_eq.mp ho).symm |
              exact Nat.compare_eq_lt.mp ho | exact Nat.compare_eq_gt.mp ho |
              exact Nat.le_of_eq (Nat.compare_eq_eq.mp ho) |
              exact Nat.le_of_eq (Nat.compare_eq_eq.mp ho).symm |
              exact Nat.le_of_lt (Nat.compare_eq_lt.mp ho) |
              exact Nat.le_of_lt (Nat.compare_eq_gt.mp ho))
        | cases h

/-- **The ordering check is sound**: a fact orders the two instances. -/
theorem orderedOk_sound {ls : Loops} {facts : List Fact} {v w : Nat} {σ : Region}
    (h : orderedOk ls facts v w σ = true) {n : Nat → Nat} {R : Nat → Iter → Nat → Iter → Prop}
    (hf : ∀ f ∈ facts, f.Holds ls n R) {iv iw : Iter} (hv : Valid ls n v iv)
    (hw : Valid ls n w iw) (hr : InRegion ls v w σ iv iw) : R v iv w iw ∨ R w iw v iv := by
  simp only [orderedOk, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true,
    List.any_eq_true] at h
  obtain ⟨_, h⟩ := h
  obtain ⟨f, hfm, hfit⟩ := h _ (mem_assigns n _)
  simp only [List.mem_filter, Bool.or_eq_true] at hfm
  obtain ⟨hff, hcov⟩ := hfm
  -- The guard holds.
  have hg : GuardOk n f.guard := by
    intro x hx
    simp only [guardFits, List.all_eq_true, Bool.or_eq_true, Bool.and_eq_true, beq_iff_eq] at hfit
    rcases hfit x hx with ⟨hin, hz⟩ | hl
    · rw [hz]
      rcases hin with hin | hin
      · have := hv _ hin; simp; omega
      · have := hw _ hin; simp; omega
    · exact lookup_map_eq (g := fun L => n L == 0) hl
  -- The pattern matches.
  have hmatch : ∀ fwd, covers ls v w σ fwd f = true →
      Matches ls n f.pat (if fwd then v else w) (if fwd then iv else iw)
        (if fwd then w else v) (if fwd then iw else iv) := by
    intro fwd hc L
    simp only [covers, Bool.and_eq_true, beq_iff_eq, List.all_eq_true, Bool.or_eq_true] at hc
    obtain ⟨_, hall⟩ := hc
    simp only [Pat.get]
    cases hfd : f.pat.find? (·.1 == L) with
    | none => rfl
    | some x =>
      have hxL := List.find?_some hfd
      simp only [beq_iff_eq] at hxL
      subst hxL
      simp only [Option.map_some, Option.getD_some]
      rcases hall x (List.mem_of_find?_eq_some hfd) with h | ⟨⟨hvL, hwL⟩, hal⟩
      · rw [h]; rfl
      · have := allowed_holds (N := n x.1) hal (hr x.1 hvL hwL)
        cases fwd <;> simpa [side, hvL, hwL] using this
  rcases hcov with hc | hc
  · have hs : f.src = v := by simp [covers] at hc; exact hc.1.1
    have hd : f.dst = w := by simp [covers] at hc; exact hc.1.2
    left
    have := hf f hff hg iv iw (hs ▸ hv) (hd ▸ hw) (by simpa [hs, hd] using hmatch true hc)
    rwa [hs, hd] at this
  · have hs : f.src = w := by simp [covers] at hc; exact hc.1.1
    have hd : f.dst = v := by simp [covers] at hc; exact hc.1.2
    right
    have := hf f hff hg iw iv (hs ▸ hw) (hd ▸ hv) (by simpa [hs, hd] using hmatch false hc)
    rwa [hs, hd] at this

open Chan in
/-- **Race-freedom for every bound**: if the certificate checks, every channel program the template
stands for, for any trip counts, is race-free. -/
theorem raceFree_of_certOk {T : Template} (hc : T.certOk = true) {n : Nat → Nat} {p : Prog}
    {fp : LFp} {num : Nat → Iter → Nat} {loc : Nat → Iter → Int → Nat × Int} {exempt : Nat → Prop}
    {S : Chan.Label → Prop} (hr : Realizes T n p fp num loc exempt S) : Chan.RaceFree p fp S := by
  intro x y hSx hSy hne hconf
  have hconf' := hconf
  obtain ⟨ax, hax, ay, hay, hcf⟩ := hconf
  by_cases hex0 : exempt ax.buf
  · exact hr.exempt_ordered x y ax ay hSx hSy hne hax hay hcf hex0
  have hcf' := hcf
  obtain ⟨hbuf, hwr, e, hex, hey⟩ := hcf
  obtain ⟨v, iv, hvlt, hvv, hfx, hsx, ta, hta, hkx, hpx⟩ := hr.cover x hSx ax hax hex0
  obtain ⟨w, iw, hwlt, hwv, hfy, hsy, tb, htb, hky, hpy⟩ := hr.cover y hSy ay hay (hbuf ▸ hex0)
  by_cases hu : num v iv = num w iw
  · exact hr.self x y _ hSx hSy hne hconf' hfx hsx (hu ▸ hfy) (hu ▸ hsy)
  obtain ⟨q, hq, hqe⟩ := hpx e hex
  obtain ⟨q', hq', hq'e⟩ := hpy e hey
  obtain ⟨hbeq, hbit, hpeq⟩ := hr.loc_inj ta.buf iv _ tb.buf iw _ (by rw [← hqe, ← hq'e, hbuf])
  -- The reachability the facts speak of.
  let R : Nat → Iter → Nat → Iter → Prop := fun a ia b ib => DepGraph.Reach p.graph (num a ia) (num b ib)
  have htrans : ∀ a ia c ic b ib, R a ia c ic → R c ic b ib → R a ia b ib :=
    fun _ _ _ _ _ _ h₁ h₂ => h₁.trans h₂
  have hinit : ∀ f ∈ T.edges ++ (List.range T.loops.size).map (reflFact T.loops),
      f.Holds T.loops n R := by
    intro f hf
    rcases List.mem_append.mp hf with hf | hf
    · exact hr.edges f hf
    · obtain ⟨a, _, rfl⟩ := List.mem_map.mp hf
      exact reflFact_holds (fun a ia ib h => by
        show DepGraph.Reach _ _ _; rw [hr.ext a ia ib h]; exact .refl _) a
  have hfacts0 : ∀ f ∈ T.facts, f.Holds T.loops n R := by
    have hp : ∀ f ∈ prune [] (T.edges ++ (List.range T.loops.size).map (reflFact T.loops)),
        f.Holds T.loops n R := fun f hf => hinit f (mem_prune hf)
    exact closeSN_holds htrans hp hp
  have hfacts : ∀ v w, ∀ f ∈ (byPair T.facts).getD (v, w) [], f.Holds T.loops n R :=
    fun _ _ f hf => hfacts0 f (mem_byPair hf)
  -- The pair passes `pairOk`.
  have hp : pairOk T (fun v w => (byPair T.facts).getD (v, w) []) v w ta tb = true := by
    simp only [Template.certOk, List.all_eq_true, List.mem_range] at hc
    exact hc v hvlt w hwlt ta hta tb htb
  have hconfl : (ta.buf == tb.buf && (ta.write || tb.write)) = true := by
    simp only [hbeq, beq_self_eq_true, Bool.true_and, Bool.or_eq_true]
    rcases hwr with h | h
    · exact Or.inl (hkx h)
    · exact Or.inr (hky h)
  simp only [pairOk, hconfl, Bool.not_true, Bool.false_or, List.all_eq_true] at hp
  -- The region the two instances are in.
  let C := (T.loops[v]?.getD []).filter (inL T.loops w)
  let σ := C.map fun L => (L, compare (iv L) (iw L))
  have hin : InRegion T.loops v w σ iv iw := by
    intro L hvL hwL
    rw [ordOf_map]
    simp only [C, List.mem_filter]
    exact ⟨by simpa [inL] using hvL, hwL⟩
  have hσ := hp σ (mem_regions iv iw C)
  simp only [Bool.or_eq_true] at hσ
  rcases hσ with ((hsame | hdiff) | hord) | hdis
  · -- One instance.
    simp only [Bool.and_eq_true, beq_iff_eq, List.all_eq_true] at hsame
    obtain ⟨rfl, hall⟩ := hsame
    apply absurd _ hu
    apply hr.ext
    intro L hL
    have := hall (L, compare (iv L) (iw L)) (List.mem_map.mpr ⟨L, by simp [C, hL]; simpa [inL] using hL, rfl⟩)
    simp only [beq_iff_eq] at this
    exact Nat.compare_eq_eq.mp this
  · -- Different buffer instances.
    simp only [List.any_eq_true, Bool.and_eq_true, bne_iff_ne, ne_eq] at hdiff
    obtain ⟨L, hL, ⟨hvL, hwL⟩, hne'⟩ := hdiff
    apply absurd _ hne'
    rw [← hin L hvL hwL, ← hbeq] at *
    rw [hbit L hL]
    exact Nat.compare_eq_eq.mpr rfl
  · -- Ordered by a fact.
    have hf2 : ∀ f ∈ (byPair T.facts).getD (v, w) [] ++ (byPair T.facts).getD (w, v) [],
        f.Holds T.loops n R := fun f hf => (List.mem_append.mp hf).elim (hfacts v w f) (hfacts w v f)
    rcases orderedOk_sound hord hf2 hvv hwv hin with h | h
    · left
      exact (hb_finishers hfx).trans ((hb_finish_start h hu).trans (hb_starters hsy))
    · right
      exact (hb_finishers hfy).trans ((hb_finish_start h (Ne.symm hu)).trans (hb_starters hsx))
  · -- Disjoint positions.
    exact absurd hpeq (disjointOk_sound hdis hr.bounds hvv hwv hin hq hq')

end LoopCert

end

end Veir.Air
