module

public import Veir.Air.ChanWitness
public import Veir.Air.LoopCert

namespace Veir.Air

@[expose] public section

/-! # Phase 2b: completion for every trip count

See `SCALE_DESIGN.md` §3.2. A program completes when its labels can be ranked so that everything a
label waits for (`hbPreds`) ranks lower (`completes_of_rank`). The ranking is given on a loop
template extended with channels and checked there, for every trip count.
-/

namespace Chan

variable {p : Prog}

/-- `run_sorted` for any irreflexive `r`: labels listed so that none comes after one it is `r`-below,
each after its predecessors (fired before, or `r`-below it in the list), form an execution. -/
theorem run_sorted_rel (r : Label → Label → Prop) (hirr : ∀ a, ¬ r a a) {F s : List Label}
    (hs : s.Pairwise fun a b => ¬ r b a) (hnd : s.Nodup) (hen : ∀ l ∈ s, ∃ H, En p H l)
    (hn : ∀ l ∈ s, l ∉ F) (hpre : ∀ l ∈ s, ∀ z ∈ hbPreds p l, z ∈ F ∨ (z ∈ s ∧ r z l)) :
    ∃ G, Run p F s G := by
  induction s generalizing F with
  | nil => exact ⟨F, .nil F⟩
  | cons l s ih =>
    obtain ⟨hl, hs'⟩ := List.pairwise_cons.mp hs
    obtain ⟨hln, hnd'⟩ := List.nodup_cons.mp hnd
    obtain ⟨H, hH⟩ := hen l (List.mem_cons_self ..)
    have hEn : En p F l := en_of_preds hH fun z hz => by
      rcases hpre l (List.mem_cons_self ..) z hz with h | ⟨hz', hlt⟩
      · exact h
      · rcases List.mem_cons.mp hz' with rfl | hz'
        · exact absurd hlt (hirr _)
        · exact absurd hlt (hl z hz')
    obtain ⟨G, r'⟩ := ih (F := l :: F) hs' hnd' (fun m hm => hen m (List.mem_cons_of_mem _ hm))
      (fun m hm h => by
        rcases List.mem_cons.mp h with rfl | h
        · exact hln hm
        · exact hn m (List.mem_cons_of_mem _ hm) h)
      (fun m hm z hz => by
        rcases hpre m (List.mem_cons_of_mem _ hm) z hz with h | ⟨hz', hlt⟩
        · exact Or.inl (List.mem_cons_of_mem _ h)
        · rcases List.mem_cons.mp hz' with rfl | hz'
          · exact Or.inl (List.mem_cons_self ..)
          · exact Or.inr ⟨hz', hlt⟩)
    exact ⟨G, .cons hEn (hn l (List.mem_cons_self ..)) r'⟩

/-- **Completion from a ranking**: labels `L` (every event's finish among them), each enabled once
all of `L` has fired, each waiting only for labels of `L` of a lower `key`: the program completes. -/
theorem completes_of_rank (L : List Label) (key : Label → List Nat) (hnd : L.Nodup)
    (hen : ∀ l ∈ L, En p L l) (hpre : ∀ l ∈ L, ∀ z ∈ hbPreds p l, z ∈ L ∧ key z < key l)
    (hfin : ∀ v, v < p.graph.size → Label.finish v ∈ L) :
    ∃ t G, Run p [] t G ∧ Done p G := by
  let le : Label → Label → Bool := fun a b => decide (key a ≤ key b)
  have hperm := List.mergeSort_perm L le
  have hsort : (L.mergeSort le).Pairwise fun a b => le a b = true :=
    List.pairwise_mergeSort (fun a b c hab hbc => by
        simp only [le, decide_eq_true_eq] at hab hbc ⊢; exact List.le_trans hab hbc)
      (fun a b => by
        simp only [le, Bool.or_eq_true, decide_eq_true_eq]; exact List.le_total _ _) L
  have hmem : ∀ l, l ∈ L.mergeSort le ↔ l ∈ L := fun l => hperm.mem_iff
  obtain ⟨G, r⟩ := run_sorted_rel (p := p) (F := []) (fun a b => key a < key b)
    (fun a => List.lt_irrefl _)
    (hsort.imp fun h => by simp only [le, decide_eq_true_eq] at h; exact List.not_lt.mpr h)
    (hperm.nodup_iff.mpr hnd)
    (fun l hl => ⟨L, hen l ((hmem l).mp hl)⟩)
    (fun _ _ h => by simp at h)
    (fun l hl z hz => by
      obtain ⟨hzL, hlt⟩ := hpre l ((hmem l).mp hl) z hz
      exact Or.inr ⟨(hmem z).mpr hzL, hlt⟩)
  refine ⟨_, G, r, fun v hv => ?_⟩
  exact (Run.mem r _).mpr (Or.inl ((hmem _).mpr (hfin v hv)))

/-- Without repeats. -/
def dedup (L : List Label) : List Label := L.foldr (fun a acc => if a ∈ acc then acc else a :: acc) []

theorem mem_dedup {L : List Label} {a : Label} : a ∈ dedup L ↔ a ∈ L := by
  induction L with
  | nil => simp [dedup]
  | cons b L ih =>
    simp only [dedup, List.foldr_cons] at ih ⊢
    split
    · next h =>
      rw [ih]; simp only [List.mem_cons]
      constructor
      · exact Or.inr
      · rintro (rfl | h')
        · exact ih.mp h
        · exact h'
    · rw [List.mem_cons, List.mem_cons, ih]

theorem nodup_dedup (L : List Label) : (dedup L).Nodup := by
  induction L with
  | nil => simp [dedup]
  | cons b L ih =>
    simp only [dedup, List.foldr_cons] at ih ⊢
    split
    · exact ih
    · next h => exact List.nodup_cons.mpr ⟨h, ih⟩

/-- `completes_of_rank` for labels with repeats. -/
theorem completes_of_rank' (L : List Label) (key : Label → List Nat)
    (hen : ∀ l ∈ L, En p L l) (hpre : ∀ l ∈ L, ∀ z ∈ hbPreds p l, z ∈ L ∧ key z < key l)
    (hfin : ∀ v, v < p.graph.size → Label.finish v ∈ L) :
    ∃ t G, Run p [] t G ∧ Done p G :=
  completes_of_rank (dedup L) key (nodup_dedup L)
    (fun l hl => (hen l (mem_dedup.mp hl)).mono fun z hz => mem_dedup.mpr hz)
    (fun l hl z hz => by
      obtain ⟨h1, h2⟩ := hpre l (mem_dedup.mp hl) z hz
      exact ⟨mem_dedup.mpr h1, h2⟩)
    (fun v hv => mem_dedup.mpr (hfin v hv))

end Chan

/-! ### The certificate -/

namespace LoopDead

open LoopCert

/-- A run of a stream's elements that one event moves in each iteration: `m` of them, from `off`. -/
structure Seg where
  ev : Nat
  off : Nat
  m : Nat
deriving Inhabited, Repr

/-- A stream of the template. In each iteration of its loop (or once, without a loop) its puts move
`per` elements, each put event a run of them (`puts`); per slot, its gets likewise (`slots`: the runs
and the elements per iteration; no run: nothing gets them, which only a buffered stream allows);
`rate` elements per time unit of their class; and the places of its labels in the order of one time
unit. -/
structure DStream where
  puts : List Seg
  per : Nat
  slots : List (List Seg × Nat)
  buffered : Bool
  rate : Nat
  πread : Nat
  πpush : Nat
  πpull : Nat
  πxfer : Nat
  /-- Every side moves all of an instance's elements in one instance of its events, all in the same
  loops: the stream lives in one instance (a DMA's elements, put and got by the DMA itself). -/
  isLocal : Bool := false
deriving Inhabited, Repr

/-- A stream's first put event. -/
def DStream.head (σ : DStream) : Nat := (σ.puts.head?.map (·.ev)).getD 0

/-- The ranking (`SCALE_DESIGN.md` §3.2): per loop its alignment class and scale; the classes in
the key's order; per event the classes it comes after (outside them; before the others it is
outside of), its start and finish offsets in each of its loops, and the places of its start and
finish in the order of one time unit; the streams. -/
structure DCert where
  T : Template
  cls : Array Nat
  scale : Array Nat
  order : List Nat
  top : Array (List Nat)
  sOff : Array (List (Nat × Nat))
  fOff : Array (List (Nat × Nat))
  πs : Array Nat
  πf : Array Nat
  streams : Array DStream
deriving Inhabited

def offOf (l : List (Nat × Nat)) (L : Nat) : Nat := ((l.find? (·.1 == L)).map (·.2)).getD 0

namespace DCert

variable (D : DCert)

/-- The loop of event `v` in class `C`, if any. -/
def loopIn (v C : Nat) : Option Nat := (D.T.loops[v]?.getD []).find? fun L => D.cls[L]! == C

def isTop (v C : Nat) : Bool := (D.top[v]?.getD []).contains C

/-- An event instance's coordinate in class `C`: its time unit (start or finish) inside a loop of
`C`, else `0` before it all or `tot C + 2` after it all. -/
def coordEv (tot : Nat → Nat) (v : Nat) (it : Iter) (fin : Bool) (C : Nat) : Nat :=
  match D.loopIn v C with
  | some L => 1 + D.scale[L]! * it L + offOf (if fin then D.fOff[v]?.getD [] else D.sOff[v]?.getD []) L
  | none => if D.isTop v C then tot C + 2 else 0

def keyEv (tot : Nat → Nat) (v : Nat) (it : Iter) (fin : Bool) : List Nat :=
  D.order.map (D.coordEv tot v it fin) ++ [if fin then D.πf[v]! else D.πs[v]!, 0]

/-- A stream's loop: its first put's. -/
def sLoop (σ : DStream) : Option Nat := (D.T.loops[σ.head]?.getD []).head?

/-- Element `e`'s coordinate in class `C`: its time unit in its stream's class, else its first
put's. -/
def coordEl (tot : Nat → Nat) (σ : DStream) (e : Nat) (it : Iter) (C : Nat) : Nat :=
  if σ.isLocal then D.coordEv tot σ.head it false C else
  match D.sLoop σ with
  | some Lp => if D.cls[Lp]! == C then 1 + e / σ.rate else D.coordEv tot σ.head (fun _ => 0) false C
  | none => D.coordEv tot σ.head (fun _ => 0) false C

/-- An element's key; `it` is its instance's iterations, used by an instance-local stream. -/
def keyEl (tot : Nat → Nat) (σ : DStream) (e : Nat) (it : Iter) (π : Nat) : List Nat :=
  D.order.map (D.coordEl tot σ e it) ++ [π, e]

end DCert

/-! ### Comparing keys -/

/-- Class by class: `some true` strictly below, `some false` equal, `none` not established. The
first class not equal decides; all equal, `fin`. -/
def lexChk (cmp : Nat → Option Bool) (fin : Bool) : List Nat → Bool
  | [] => fin
  | C :: cs => match cmp C with
    | some true => true
    | some false => lexChk cmp fin cs
    | none => false

theorem lt_of_lexChk {cmp : Nat → Option Bool} {fin : Bool} {f g : Nat → Nat} {tf tg : List Nat}
    (hlt : ∀ C, cmp C = some true → f C < g C) (heq : ∀ C, cmp C = some false → f C = g C)
    (hfin : fin = true → tf < tg) :
    ∀ cs, lexChk cmp fin cs = true → cs.map f ++ tf < cs.map g ++ tg
  | [], h => hfin h
  | C :: cs, h => by
    simp only [lexChk] at h
    simp only [List.map_cons, List.cons_append]
    split at h
    · next hc => exact List.cons_lt_cons_iff.mpr (Or.inl (hlt C hc))
    · next hc => exact List.cons_lt_cons_iff.mpr (Or.inr ⟨heq C hc, lt_of_lexChk hlt heq hfin cs h⟩)
    · simp at h

/-- Componentwise no greater, and the tails strictly below: strictly below. -/
theorem lt_of_le_map {f g : Nat → Nat} {tf tg : List Nat} (h : tf < tg) :
    ∀ cs : List Nat, (∀ C ∈ cs, f C ≤ g C) → cs.map f ++ tf < cs.map g ++ tg
  | [], _ => h
  | C :: cs, hle => by
    simp only [List.map_cons, List.cons_append]
    rcases Nat.lt_or_eq_of_le (hle C (List.mem_cons_self ..)) with hc | hc
    · exact List.cons_lt_cons_iff.mpr (Or.inl hc)
    · exact List.cons_lt_cons_iff.mpr (Or.inr ⟨hc, lt_of_le_map h cs
        fun C' hC' => hle C' (List.mem_cons_of_mem _ hC')⟩)

theorem pair_lt {a b c d : Nat} (h : a < c ∨ (a = c ∧ b < d)) : [a, b] < [c, d] := by
  rcases h with h | ⟨rfl, h⟩
  · exact List.cons_lt_cons_iff.mpr (Or.inl h)
  · exact List.cons_lt_cons_iff.mpr (Or.inr ⟨rfl, List.cons_lt_cons_iff.mpr (Or.inl h)⟩)

/-! ### The checker -/

namespace DCert

variable (D : DCert)

def loopsOf (v : Nat) : List Nat := D.T.loops[v]?.getD []

/-- An event's offsets lie in its iteration's units, its start no later than its finish. -/
def evOk (v : Nat) : Bool :=
  (D.loopsOf v).all (fun L => offOf (D.sOff[v]?.getD []) L ≤ offOf (D.fOff[v]?.getD []) L &&
    offOf (D.fOff[v]?.getD []) L < D.scale[L]!) && decide (D.πs[v]! < D.πf[v]!)

/-- For an edge `f`, class `C`: the finish of the source below (`some true`) or equal to
(`some false`) the start of the target, for every pair of instances it relates. -/
def cmpEdge (f : Fact) (C : Nat) : Option Bool :=
  match D.loopIn f.src C, D.loopIn f.dst C with
  | some L, some L' =>
    if L == L' then
      match f.pat.get L with
      | .eq =>
        let a := offOf (D.fOff[f.src]?.getD []) L
        let b := offOf (D.sOff[f.dst]?.getD []) L
        if a < b then some true else if a == b then some false else none
      | .succ => some true
      | _ => none
    else none
  | some _, none => if D.isTop f.dst C then some true else none
  | none, some _ => if D.isTop f.src C then none else some true
  | none, none =>
    match D.isTop f.src C, D.isTop f.dst C with
    | false, true => some true
    | false, false => some false
    | true, true => some false
    | true, false => none

def edgeOk (f : Fact) : Bool := lexChk (D.cmpEdge f) (decide (D.πf[f.src]! < D.πs[f.dst]!)) D.order

end DCert

/-! ### Soundness of the edge check -/

section

variable {D : DCert} {n tot : Nat → Nat}

/-- The bounds of the loops of a class agree: `scale * n` is the class's length in units. -/
def Aligned (D : DCert) (n tot : Nat → Nat) : Prop := ∀ L, D.scale[L]! * n L = tot D.cls[L]!

theorem loopIn_spec {v C L : Nat} (h : D.loopIn v C = some L) :
    L ∈ D.loopsOf v ∧ D.cls[L]! = C := by
  unfold DCert.loopIn at h
  have h1 := List.mem_of_find?_eq_some h
  have h2 := List.find?_some h
  exact ⟨h1, by simpa using h2⟩

theorem inL_of_loopsOf {v L : Nat} (h : L ∈ D.loopsOf v) : inL D.T.loops v L = true := by
  simp only [inL]; exact List.elem_eq_true_of_mem h

theorem offs_of_evOk {v L : Nat} (h : D.evOk v = true) (hL : L ∈ D.loopsOf v) :
    offOf (D.sOff[v]?.getD []) L ≤ offOf (D.fOff[v]?.getD []) L ∧
    offOf (D.fOff[v]?.getD []) L < D.scale[L]! := by
  simp only [DCert.evOk, Bool.and_eq_true, List.all_eq_true, decide_eq_true_eq] at h
  exact h.1 L hL

/-- Inside a loop of `C`, a coordinate is at most the class's length. -/
theorem coord_le_tot {v C L : Nat} {it : Iter} {fin : Bool} (hal : Aligned D n tot)
    (hl : D.loopIn v C = some L) (hok : D.evOk v = true)
    (hv : LoopCert.Valid D.T.loops n v it) : D.coordEv tot v it fin C ≤ tot C := by
  obtain ⟨hm, hc⟩ := loopIn_spec hl
  have hlt := hv L (inL_of_loopsOf hm)
  obtain ⟨h1, h2⟩ := offs_of_evOk hok hm
  have hal' := hal L
  rw [hc] at hal'
  simp only [DCert.coordEv, hl]
  have : D.scale[L]! * it L + D.scale[L]! ≤ D.scale[L]! * n L := by
    rw [← Nat.mul_succ]; exact Nat.mul_le_mul_left _ hlt
  cases fin <;> simp <;> omega

theorem edge_lt {f : Fact} (hal : Aligned D n tot) (hok : D.edgeOk f = true)
    (hsa : D.evOk f.src = true) (hsb : D.evOk f.dst = true) {ia ib : Iter}
    (hva : LoopCert.Valid D.T.loops n f.src ia) (hvb : LoopCert.Valid D.T.loops n f.dst ib)
    (hm : Matches D.T.loops n f.pat f.src ia f.dst ib) :
    D.keyEv tot f.src ia true < D.keyEv tot f.dst ib false := by
  unfold DCert.keyEv
  refine lt_of_lexChk (cmp := D.cmpEdge f) ?_ ?_ ?_ _ hok
  · intro C hc
    unfold DCert.cmpEdge at hc
    split at hc
    · next L L' hL hL' =>
      split at hc
      · next hLL =>
        simp only [beq_iff_eq] at hLL; subst hLL
        obtain ⟨hma, _⟩ := loopIn_spec hL
        obtain ⟨hmb, _⟩ := loopIn_spec hL'
        have hr := hm L
        rw [show inL D.T.loops f.src L = true from inL_of_loopsOf hma,
          show inL D.T.loops f.dst L = true from inL_of_loopsOf hmb] at hr
        have hfa := (offs_of_evOk hsa hma).2
        simp only [DCert.coordEv, hL, hL', ite_true, Bool.false_eq_true, ite_false]
        split at hc
        · next hg =>
          rw [hg] at hr; simp only [side, Rel.holds, beq_iff_eq, ite_true] at hr
          rw [hr]
          dsimp only at hc
          split at hc
          · omega
          · split at hc <;> simp at hc
        · next hg =>
          rw [hg] at hr; simp only [side, Rel.holds, beq_iff_eq, ite_true] at hr
          rw [hr, Nat.mul_succ]; omega
        · simp at hc
      · simp at hc
    · next L hL hL' =>
      split at hc
      · next ht =>
        have := coord_le_tot (fin := true) hal hL hsa hva
        have hb : D.coordEv tot f.dst ib false C = tot C + 2 := by
          simp [DCert.coordEv, hL', ht]
        rw [hb]; omega
      · simp at hc
    · next L hL hL' =>
      split at hc
      · simp at hc
      · next ht =>
        simp only [DCert.coordEv, hL, hL', ht, Bool.false_eq_true, ite_false]; omega
    · next hL hL' =>
      simp only [DCert.coordEv, hL, hL']
      split at hc <;> simp_all
  · intro C hc
    unfold DCert.cmpEdge at hc
    split at hc
    · next L L' hL hL' =>
      split at hc
      · next hLL =>
        simp only [beq_iff_eq] at hLL; subst hLL
        obtain ⟨hma, _⟩ := loopIn_spec hL
        obtain ⟨hmb, _⟩ := loopIn_spec hL'
        have hr := hm L
        rw [show inL D.T.loops f.src L = true from inL_of_loopsOf hma,
          show inL D.T.loops f.dst L = true from inL_of_loopsOf hmb] at hr
        simp only [DCert.coordEv, hL, hL', ite_true, Bool.false_eq_true, ite_false]
        split at hc
        · next hg =>
          rw [hg] at hr; simp only [side, Rel.holds, beq_iff_eq, ite_true] at hr
          rw [hr]
          dsimp only at hc
          split at hc
          · simp at hc
          · split at hc
            · next he => simp only [beq_iff_eq] at he; omega
            · simp at hc
        · simp at hc
        · simp at hc
      · simp at hc
    · split at hc <;> simp at hc
    · split at hc <;> simp at hc
    · next hL hL' =>
      simp only [DCert.coordEv, hL, hL']
      split at hc <;> simp_all
  · intro h
    simp only [decide_eq_true_eq] at h
    simp only [ite_true, Bool.false_eq_true, ite_false]
    exact pair_lt (Or.inl h)

end

namespace DCert

variable (D : DCert)

/-- One side of a stream (its puts, or one slot's gets), `P` elements per iteration: each event in
one loop of the stream's class, `P` being `rate` per unit of it, starting at its run's first
element's unit and finishing at its last's; or, when the stream has no loop, none; and where the
first put is for the other classes. -/
def sideOk (σ : DStream) (segs : List Seg) (P : Nat) : Bool :=
  (if σ.isLocal then
    -- In one instance: the same loops as the first put, starting no later and finishing no
    -- earlier than it starts.
    segs.all fun g => D.loopsOf g.ev == D.loopsOf σ.head && (D.loopsOf σ.head).all fun L =>
      decide (offOf (D.sOff[g.ev]?.getD []) L ≤ offOf (D.sOff[σ.head]?.getD []) L) &&
      decide (offOf (D.sOff[σ.head]?.getD []) L ≤ offOf (D.fOff[g.ev]?.getD []) L)
  else match D.sLoop σ with
   | some Lp => segs.all fun g => match D.loopsOf g.ev with
       | [L] => D.cls[L]! == D.cls[Lp]! && P == σ.rate * D.scale[L]! && decide (0 < D.scale[L]!) &&
           decide (0 < g.m) && offOf (D.sOff[g.ev]?.getD []) L == g.off / σ.rate &&
           offOf (D.fOff[g.ev]?.getD []) L == (g.off + g.m - 1) / σ.rate
       | _ => false
   | none => segs.all fun g => D.loopsOf g.ev == []) &&
  segs.all fun g => D.order.all fun C => D.isTop g.ev C == D.isTop σ.head C

/-- Every side checks; a stream nothing gets from is buffered. -/
def shapeOk (σ : DStream) : Bool :=
  decide (0 < σ.rate) && !σ.puts.isEmpty && D.sideOk σ σ.puts σ.per &&
  σ.slots.all (fun sg => D.sideOk σ sg.1 sg.2) &&
  (σ.buffered || (!σ.slots.isEmpty && σ.slots.all fun sg => !sg.1.isEmpty))

/-- The order of one unit: the puts start before the elements are read, the gets before they
arrive; reads, pushes and arrivals in that order; every end finishes after. -/
def rankOk (σ : DStream) : Bool :=
  σ.puts.all (fun g => decide (D.πs[g.ev]! < σ.πread)) &&
  if σ.buffered then
    decide (σ.πread < σ.πpush) && decide (σ.πpush < σ.πpull) &&
    σ.puts.all (fun g => decide (σ.πpush < D.πf[g.ev]!)) &&
    σ.slots.all fun sg => sg.1.all fun g => decide (D.πs[g.ev]! < σ.πpull) && decide (σ.πpull < D.πf[g.ev]!)
  else
    decide (σ.πread < σ.πxfer) && σ.puts.all (fun g => decide (σ.πxfer < D.πf[g.ev]!)) &&
    σ.slots.all fun sg => sg.1.all fun g => decide (D.πs[g.ev]! < σ.πxfer) && decide (σ.πxfer < D.πf[g.ev]!)

def streamOk (σ : DStream) : Bool := D.shapeOk σ && D.rankOk σ

/-- **The check**: events, edges and streams. -/
def deadOk : Bool :=
  (List.range D.T.loops.size).all D.evOk && D.T.edges.all D.edgeOk && D.streams.all D.streamOk

end DCert

section

variable {D : DCert} {tot : Nat → Nat}

theorem coordEv_congr {v C : Nat} {it it' : Iter} {fin : Bool}
    (h : ∀ L ∈ D.loopsOf v, it L = it' L) : D.coordEv tot v it fin C = D.coordEv tot v it' fin C := by
  unfold DCert.coordEv
  split
  · next L hL => rw [h L (loopIn_spec hL).1]
  · rfl

theorem loopIn_single {v Lp C : Nat} (h : D.loopsOf v = [Lp]) :
    D.loopIn v C = if D.cls[Lp]! = C then some Lp else none := by
  unfold DCert.loopIn
  simp only [DCert.loopsOf] at h
  rw [h]; simp only [List.find?_cons, List.find?_nil]
  split <;> simp_all

theorem loopIn_nil {v C : Nat} (h : D.loopsOf v = []) : D.loopIn v C = none := by
  unfold DCert.loopIn
  simp only [DCert.loopsOf] at h
  rw [h]; rfl

theorem coordEv_out {v C : Nat} {it : Iter} {fin : Bool} (h : D.loopIn v C = none) :
    D.coordEv tot v it fin C = if D.isTop v C then tot C + 2 else 0 := by
  simp [DCert.coordEv, h]

end

section

variable {D : DCert} {tot : Nat → Nat}

/-- `r` elements per unit, `s` units per iteration: element `e`'s unit is its iteration's first,
plus its place in the iteration. -/
theorem div_split (e r s : Nat) (hr : 0 < r) : e / r = s * (e / (r * s)) + e % (r * s) / r := by
  have h := Nat.div_add_mod e (r * s)
  have : e / r = (e % (r * s) + r * (s * (e / (r * s)))) / r := by
    rw [← Nat.mul_assoc]; congr 1; omega
  rw [this, Nat.add_mul_div_left _ _ hr, Nat.add_comm]

/-- An element of a run lies between the units of the run's first and last elements. -/
theorem seg_bounds {e r s off m : Nat} (hr : 0 < r) (hoff : off ≤ e % (r * s))
    (hlt : e % (r * s) < off + m) :
    s * (e / (r * s)) + off / r ≤ e / r ∧ e / r ≤ s * (e / (r * s)) + (off + m - 1) / r := by
  rw [div_split e r s hr]
  exact ⟨Nat.add_le_add_left (Nat.div_le_div_right hoff) _,
    Nat.add_le_add_left (Nat.div_le_div_right (by omega)) _⟩

theorem shape_parts {σ : DStream} (hs : D.shapeOk σ = true) :
    0 < σ.rate ∧ σ.puts ≠ [] ∧ D.sideOk σ σ.puts σ.per = true ∧
    (∀ sg ∈ σ.slots, D.sideOk σ sg.1 sg.2 = true) ∧
    (σ.buffered = false → σ.slots ≠ [] ∧ ∀ sg ∈ σ.slots, sg.1 ≠ []) := by
  simp only [DCert.shapeOk, Bool.and_eq_true, decide_eq_true_eq, Bool.not_eq_true',
    List.isEmpty_eq_false_iff, List.all_eq_true, Bool.or_eq_true] at hs
  obtain ⟨⟨⟨⟨hr, hp⟩, hpo⟩, hso⟩, hb⟩ := hs
  refine ⟨hr, hp, hpo, hso, fun hbf => ?_⟩
  rcases hb with hb | ⟨hne, hall⟩
  · rw [hbf] at hb; exact absurd hb (by simp)
  · exact ⟨hne, fun sg hsg => by simpa using hall sg hsg⟩

/-- The first put's loops: the stream's loop, or none. -/
theorem head_loops {σ : DStream} (hs : D.shapeOk σ = true) (hloc : σ.isLocal = false) :
    (∃ Lp, D.sLoop σ = some Lp ∧ D.loopsOf σ.head = [Lp]) ∨
    (D.sLoop σ = none ∧ D.loopsOf σ.head = []) := by
  obtain ⟨_, hp, hpo, _⟩ := shape_parts hs
  obtain ⟨g, gs, hgs⟩ := List.exists_cons_of_ne_nil hp
  have hhead : σ.head = g.ev := by simp [DStream.head, hgs]
  have hsl : D.sLoop σ = (D.loopsOf σ.head).head? := rfl
  cases hS : D.sLoop σ with
  | some Lp =>
    simp only [DCert.sideOk, hloc, hS, Bool.false_eq_true, ite_false, Bool.and_eq_true,
      List.all_eq_true] at hpo
    have := hpo.1 g (by rw [hgs]; exact List.mem_cons_self ..)
    rw [← hhead] at this
    split at this
    · next L hL =>
      rw [hS, hL] at hsl
      simp only [List.head?_cons, Option.some.injEq] at hsl
      exact Or.inl ⟨Lp, rfl, by rw [hL, hsl]⟩
    · simp at this
  | none =>
    rw [hS] at hsl
    exact Or.inr ⟨rfl, List.head?_eq_none_iff.mp hsl.symm⟩

/-- **An element between its run's start and finish**: for a side of a stream that checks, an
event moving element `e` (in its run, in the iteration `e / P`) starts no later and finishes no
earlier than `e`'s coordinates. -/
theorem side_coords {σ : DStream} {segs : List Seg} {P : Nat} {g : Seg} {e : Nat} {it itE : Iter}
    (hs : D.shapeOk σ = true) (hloc : σ.isLocal = false) (hside : D.sideOk σ segs P = true)
    (hg : g ∈ segs) (hoff : g.off ≤ e % P) (hlt : e % P < g.off + g.m)
    (hit : ∀ L ∈ D.loopsOf g.ev, it L = e / P) (C : Nat) (hC : C ∈ D.order) :
    D.coordEv tot g.ev it false C ≤ D.coordEl tot σ e itE C ∧
      D.coordEl tot σ e itE C ≤ D.coordEv tot g.ev it true C := by
  have hr := (shape_parts hs).1
  have hct : D.isTop g.ev C = D.isTop σ.head C := by
    simp only [DCert.sideOk, Bool.and_eq_true, List.all_eq_true, beq_iff_eq] at hside
    exact hside.2 g hg C hC
  rcases head_loops hs hloc with ⟨Lp, hS, hH⟩ | ⟨hS, hH⟩
  · simp only [DCert.sideOk, hloc, hS, Bool.false_eq_true, ite_false, Bool.and_eq_true,
      List.all_eq_true] at hside
    have hgs := hside.1 g hg
    split at hgs
    · next L hL =>
      simp only [Bool.and_eq_true, beq_iff_eq, decide_eq_true_eq] at hgs
      obtain ⟨⟨⟨⟨⟨hcl, hP⟩, hsc⟩, _⟩, hso⟩, hfo⟩ := hgs
      have hiL := hit L (by rw [hL]; exact List.mem_singleton_self _)
      simp only [DCert.coordEl, hloc, Bool.false_eq_true, ite_false, hS, DCert.coordEv,
        loopIn_single hL, loopIn_single hH]
      by_cases hc : D.cls[Lp]! = C
      · have hcL : D.cls[L]! = C := by rw [hcl, hc]
        subst hP
        have ub := seg_bounds (s := D.scale[L]!) hr hoff hlt
        simp only [hcL, hc, beq_self_eq_true, ite_true, Bool.false_eq_true, ite_false, hso, hfo, hiL]
        omega
      · have hcL : ¬ D.cls[L]! = C := by rw [hcl]; exact hc
        simp [hcL, hc, hct]
    · simp at hgs
  · simp only [DCert.sideOk, hloc, hS, Bool.false_eq_true, ite_false, Bool.and_eq_true,
      List.all_eq_true] at hside
    have hgn : D.loopsOf g.ev = [] := by simpa using hside.1 g hg
    simp [DCert.coordEl, hloc, hS, DCert.coordEv, loopIn_nil hH, loopIn_nil hgn, hct]

/-- In an instance-local stream, an element lies between the start and finish of each event moving
it, in that event's instance. -/
theorem side_coords_local {σ : DStream} {segs : List Seg} {P : Nat} {g : Seg} {e : Nat} {it itE : Iter}
    (hloc : σ.isLocal = true) (hside : D.sideOk σ segs P = true) (hg : g ∈ segs)
    (hit : ∀ L ∈ D.loopsOf g.ev, it L = itE L) (C : Nat) (hC : C ∈ D.order) :
    D.coordEv tot g.ev it false C ≤ D.coordEl tot σ e itE C ∧
      D.coordEl tot σ e itE C ≤ D.coordEv tot g.ev it true C := by
  simp only [DCert.sideOk, hloc, ite_true, Bool.and_eq_true, List.all_eq_true, beq_iff_eq,
    decide_eq_true_eq] at hside
  obtain ⟨hl, hctx⟩ := hside
  obtain ⟨hloops, hoffs⟩ := hl g hg
  have hct : D.isTop g.ev C = D.isTop σ.head C := hctx g hg C hC
  have hin : ∀ L, D.loopIn g.ev C = some L ↔ D.loopIn σ.head C = some L := by
    intro L; simp only [DCert.loopIn]; simp only [DCert.loopsOf] at hloops; rw [hloops]
  simp only [DCert.coordEl, hloc, ite_true, DCert.coordEv]
  cases hL : D.loopIn σ.head C with
  | some L =>
    have hgL := (hin L).mpr hL
    rw [hgL]
    have hm := (loopIn_spec hL).1
    have ⟨h1, h2⟩ := hoffs L hm
    have hiL := hit L (by rw [hloops]; exact hm)
    simp only [Bool.false_eq_true, ite_false, ite_true, hiL]
    omega
  | none =>
    have hgN : D.loopIn g.ev C = none := by
      cases h : D.loopIn g.ev C with
      | none => rfl
      | some L => rw [(hin L).mp h] at hL; cases hL
    rw [hgN, hct]
    exact ⟨Nat.le_refl _, Nat.le_refl _⟩

/-- Elements of a stream move to later or the same units. -/
theorem coordEl_mono {σ : DStream} {e e' : Nat} {it it' : Iter} (h : e ≤ e')
    (hit : σ.isLocal = true → it = it') (C : Nat) :
    D.coordEl tot σ e it C ≤ D.coordEl tot σ e' it' C := by
  unfold DCert.coordEl
  cases hl : σ.isLocal
  · simp only [Bool.false_eq_true, ite_false]
    split
    · split
      · exact Nat.add_le_add_left (Nat.div_le_div_right h) _
      · exact Nat.le_refl _
    · exact Nat.le_refl _
  · rw [hit hl]; exact Nat.le_refl _

end

end LoopDead

/-! ### Every label of a program -/

namespace Chan

/-- An element's labels: its read, then its push and its arrival at each slot a get takes it from
(buffered), or its transfer. -/
def elemLabels (p : Prog) (k : Nat) : List Label :=
  match p.elems[k]? with
  | some e => .read k :: (if e.buffered then .push k :: (List.range e.dsts.length).filterMap
        (fun i => if (e.dsts[i]?.bind id).isSome then some (.pull k i) else none)
      else [.xfer k])
  | none => []

def allLabels (p : Prog) : List Label :=
  (List.range p.graph.size).flatMap (fun v => [Label.start v, .finish v]) ++
  (List.range p.elems.size).flatMap (elemLabels p)

variable {p : Prog}

theorem elemLabels_k {k k' : Nat} {l : Label} (h : l ∈ elemLabels p k')
    (hl : l = .read k ∨ l = .push k ∨ (∃ i, l = .pull k i) ∨ l = .xfer k) : k' = k := by
  unfold elemLabels at h
  split at h
  · simp only [List.mem_cons] at h
    split at h
    · simp only [List.mem_cons, List.mem_filterMap, List.mem_range] at h
      rcases h with rfl | rfl | ⟨i, _, hi⟩
      · rcases hl with h | h | ⟨_, h⟩ | h <;> simp_all
      · rcases hl with h | h | ⟨_, h⟩ | h <;> simp_all
      · split at hi
        · simp only [Option.some.injEq] at hi; subst hi
          rcases hl with h | h | ⟨_, h⟩ | h <;> simp_all
        · simp at hi
    · simp only [List.mem_singleton] at h
      rcases h with rfl | rfl <;> rcases hl with h | h | ⟨_, h⟩ | h <;> simp_all
  · simp at h

theorem not_ev_elemLabels {k : Nat} {l : Label} (h : l ∈ elemLabels p k) :
    (∀ v, l ≠ .start v) ∧ (∀ v, l ≠ .finish v) := by
  unfold elemLabels at h
  split at h
  · simp only [List.mem_cons] at h
    split at h
    · simp only [List.mem_cons, List.mem_filterMap, List.mem_range] at h
      rcases h with rfl | rfl | ⟨i, _, hi⟩
      · simp
      · simp
      · split at hi
        · simp only [Option.some.injEq] at hi; subst hi; simp
        · simp at hi
    · simp only [List.mem_singleton] at h
      rcases h with rfl | rfl <;> simp
  · simp at h

theorem mem_all_start {x : Nat} : Label.start x ∈ allLabels p ↔ x < p.graph.size := by
  simp only [allLabels, List.mem_append, List.mem_flatMap, List.mem_range]
  constructor
  · rintro (⟨v, hv, h⟩ | ⟨k, _, h⟩)
    · simp only [List.mem_cons, List.mem_singleton] at h
      rcases h with h | h <;> simp_all
    · exact absurd rfl ((not_ev_elemLabels h).1 x)
  · intro h; exact Or.inl ⟨x, h, by simp⟩

theorem mem_all_finish {x : Nat} : Label.finish x ∈ allLabels p ↔ x < p.graph.size := by
  simp only [allLabels, List.mem_append, List.mem_flatMap, List.mem_range]
  constructor
  · rintro (⟨v, hv, h⟩ | ⟨k, _, h⟩)
    · simp only [List.mem_cons, List.mem_singleton] at h
      rcases h with h | h <;> simp_all
    · exact absurd rfl ((not_ev_elemLabels h).2 x)
  · intro h; exact Or.inl ⟨x, h, by simp⟩

theorem mem_all_elem {l : Label} {k : Nat}
    (hl : l = .read k ∨ l = .push k ∨ (∃ i, l = .pull k i) ∨ l = .xfer k) :
    l ∈ allLabels p ↔ l ∈ elemLabels p k := by
  simp only [allLabels, List.mem_append, List.mem_flatMap, List.mem_range]
  constructor
  · rintro (⟨v, _, h⟩ | ⟨k', _, h⟩)
    · simp only [List.mem_cons, List.mem_singleton] at h
      rcases h with h | h <;> rcases hl with h' | h' | ⟨_, h'⟩ | h' <;> simp_all
    · rw [← elemLabels_k h hl]; exact h
  · intro h
    refine Or.inr ⟨k, ?_, h⟩
    unfold elemLabels at h
    split at h
    · next e he => exact elem_lt he
    · simp at h

theorem mem_all_read {k : Nat} : Label.read k ∈ allLabels p ↔ ∃ e, p.elems[k]? = some e := by
  rw [mem_all_elem (Or.inl rfl)]
  unfold elemLabels
  split
  · simp_all
  · simp_all

theorem mem_all_push {k : Nat} :
    Label.push k ∈ allLabels p ↔ ∃ e, p.elems[k]? = some e ∧ e.buffered = true := by
  rw [mem_all_elem (Or.inr (Or.inl rfl))]
  unfold elemLabels
  split
  · next e he => split <;> simp_all
  · simp_all

theorem mem_all_pull {k i : Nat} : Label.pull k i ∈ allLabels p ↔
    ∃ e, p.elems[k]? = some e ∧ e.buffered = true ∧ ∃ d, e.dsts[i]? = some (some d) := by
  rw [mem_all_elem (Or.inr (Or.inr (Or.inl ⟨i, rfl⟩)))]
  unfold elemLabels
  split
  · next e he =>
    split
    · next hb =>
      simp only [List.mem_cons, List.mem_filterMap, List.mem_range, reduceCtorEq, false_or]
      constructor
      · rintro ⟨i', hi', hp⟩
        split at hp
        · next hs =>
          simp only [Option.some.injEq, Label.pull.injEq] at hp
          obtain ⟨_, rfl⟩ := hp
          cases hd : e.dsts[i']? with
          | none => simp [hd] at hs
          | some o =>
            cases o with
            | none => simp [hd] at hs
            | some d => exact ⟨e, he, hb, d, hd⟩
        · simp at hp
      · rintro ⟨e', he', _, d, hd⟩
        rw [he] at he'; cases he'
        exact ⟨i, (List.getElem?_eq_some_iff.mp hd).1, by simp [hd]⟩
    · simp_all
  · simp_all

theorem mem_all_xfer {k : Nat} :
    Label.xfer k ∈ allLabels p ↔ ∃ e, p.elems[k]? = some e ∧ e.buffered = false := by
  rw [mem_all_elem (Or.inr (Or.inr (Or.inr rfl)))]
  unfold elemLabels
  split
  · next e he => split <;> simp_all
  · simp_all

end Chan

/-! ### Programs realizing a certificate -/

namespace LoopDead

open LoopCert Chan

/-- How element `e` of a stream sits in the instance `it` of event `g`'s run (`P` elements per
iteration): in an instance-local stream, `it` is the element's instance `itE`; otherwise `e` is in
`g`'s run of its iteration, `e / P`. -/
def SegAt (D : DCert) (σ : DStream) (g : Seg) (P e : Nat) (itE it : Iter) : Prop :=
  if σ.isLocal then ∀ L ∈ D.loopsOf g.ev, it L = itE L
  else g.off ≤ e % P ∧ e % P < g.off + g.m ∧ ∀ L ∈ D.loopsOf g.ev, it L = e / P

/-- What element `k` of `p` is in the template: element `(elOf k).2` of stream `(elOf k).1`, put by
one of the stream's put events in the iteration of its index (within its run), got at each slot a
get takes it from likewise, after the stream's previous element. -/
structure ElemRealized (D : DCert) (p : Prog) (evOf : Nat → Nat × Iter) (elOf : Nat → Nat × Nat)
    (elIt : Nat → Iter) (k : Nat) (el : Elem) : Prop where
  stream : (elOf k).1 < D.streams.size
  buffered : el.buffered = D.streams[(elOf k).1]!.buffered
  src : ∃ x, el.src = some x ∧ x < p.graph.size ∧ ∃ g ∈ D.streams[(elOf k).1]!.puts,
    (evOf x).1 = g.ev ∧
    SegAt D D.streams[(elOf k).1]! g D.streams[(elOf k).1]!.per (elOf k).2 (elIt k) (evOf x).2
  dlen : el.dsts.length = D.streams[(elOf k).1]!.slots.length
  dsts : ∀ (i : Nat) (sg : List Seg × Nat), D.streams[(elOf k).1]!.slots[i]? = some sg →
    (sg.1 = [] → el.dsts[i]? = some none) ∧
    (sg.1 ≠ [] → ∃ x, el.dsts[i]? = some (some x) ∧ x < p.graph.size ∧ ∃ g ∈ sg.1,
      (evOf x).1 = g.ev ∧ SegAt D D.streams[(elOf k).1]! g sg.2 (elOf k).2 (elIt k) (evOf x).2)
  prev : ∀ j, el.prev = some j → j < p.elems.size ∧ (elOf j).1 = (elOf k).1 ∧
    (elOf j).2 + 1 = (elOf k).2 ∧ (D.streams[(elOf k).1]!.isLocal = true → elIt j = elIt k)

/-- **`p` realizes `D` for trip counts `n`** (class lengths `tot`): `evOf` and `elOf` give each event
and element its place in the template; every dependency of an event is an edge of the template
relating their instances; the loops of a class agree in length. -/
structure RealizesD (D : DCert) (n tot : Nat → Nat) (p : Prog) (evOf : Nat → Nat × Iter)
    (elOf : Nat → Nat × Nat) (elIt : Nat → Iter) : Prop where
  aligned : Aligned D n tot
  ev : ∀ x, x < p.graph.size →
    (evOf x).1 < D.T.loops.size ∧ LoopCert.Valid D.T.loops n (evOf x).1 (evOf x).2
  preds : ∀ x, x < p.graph.size → ∀ u ∈ p.graph.predsOf x, u < p.graph.size ∧
    ∃ f ∈ D.T.edges, f.src = (evOf u).1 ∧ f.dst = (evOf x).1 ∧
      Matches D.T.loops n f.pat f.src (evOf u).2 f.dst (evOf x).2
  elems : ∀ k el, p.elems[k]? = some el → ElemRealized D p evOf elOf elIt k el

/-- The key of a label of `p`. -/
def keyOf (D : DCert) (tot : Nat → Nat) (evOf : Nat → Nat × Iter) (elOf : Nat → Nat × Nat)
    (elIt : Nat → Iter) : Chan.Label → List Nat
  | .start x => D.keyEv tot (evOf x).1 (evOf x).2 false
  | .finish x => D.keyEv tot (evOf x).1 (evOf x).2 true
  | .read k => D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) D.streams[(elOf k).1]!.πread
  | .push k => D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) D.streams[(elOf k).1]!.πpush
  | .pull k _ => D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) D.streams[(elOf k).1]!.πpull
  | .xfer k => D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) D.streams[(elOf k).1]!.πxfer

section

variable {D : DCert} {tot : Nat → Nat}

theorem ev_lt {v : Nat} {it : Iter} (h : D.evOk v = true) :
    D.keyEv tot v it false < D.keyEv tot v it true := by
  have hπ : D.πs[v]! < D.πf[v]! := by
    simp only [DCert.evOk, Bool.and_eq_true, decide_eq_true_eq] at h; exact h.2
  unfold DCert.keyEv
  refine lt_of_le_map (pair_lt (by simp [hπ])) _ fun C _ => ?_
  unfold DCert.coordEv
  split
  · next L hL =>
    have := (offs_of_evOk h (loopIn_spec hL).1).1
    simp only [Bool.false_eq_true, ite_false, ite_true]; omega
  · exact Nat.le_refl _

theorem el_lt_el {σ : DStream} {e e' π π' : Nat} {it it' : Iter} (he : e ≤ e')
    (hit : σ.isLocal = true → it = it')
    (h : π < π' ∨ (π = π' ∧ e < e')) : D.keyEl tot σ e it π < D.keyEl tot σ e' it' π' :=
  lt_of_le_map (pair_lt h) _ fun C _ => coordEl_mono he hit C

/-- An event of a side of a stream that moves element `e`: its start ranks below `e`'s labels
after it, its finish above those before it. -/
theorem seg_lt {σ : DStream} {segs : List Seg} {P : Nat} {g : Seg} {e : Nat} {it itE : Iter}
    (hs : D.shapeOk σ = true) (hside : D.sideOk σ segs P = true) (hg : g ∈ segs)
    (hat : SegAt D σ g P e itE it) {π : Nat} :
    (D.πs[g.ev]! < π → D.keyEv tot g.ev it false < D.keyEl tot σ e itE π) ∧
    (π < D.πf[g.ev]! → D.keyEl tot σ e itE π < D.keyEv tot g.ev it true) := by
  have hc : ∀ C ∈ D.order, D.coordEv tot g.ev it false C ≤ D.coordEl tot σ e itE C ∧
      D.coordEl tot σ e itE C ≤ D.coordEv tot g.ev it true C := by
    intro C hC
    unfold SegAt at hat
    cases hl : σ.isLocal
    · simp only [hl, Bool.false_eq_true, ite_false] at hat
      exact side_coords hs hl hside hg hat.1 hat.2.1 hat.2.2 C hC
    · simp only [hl, ite_true] at hat
      exact side_coords_local hl hside hg hat C hC
  exact ⟨fun h => lt_of_le_map (pair_lt (by simp [h])) _ fun C hC => (hc C hC).1,
    fun h => lt_of_le_map (pair_lt (by simp [h])) _ fun C hC => (hc C hC).2⟩

end

end LoopDead

namespace LoopDead

open LoopCert Chan

section

variable {D : DCert} {n tot : Nat → Nat} {p : Prog} {evOf : Nat → Nat × Iter}
  {elOf : Nat → Nat × Nat} {elIt : Nat → Iter}

theorem deadOk_ev (hc : D.deadOk = true) {v : Nat} (hv : v < D.T.loops.size) : D.evOk v = true := by
  simp only [DCert.deadOk, Bool.and_eq_true, List.all_eq_true, List.mem_range] at hc
  exact hc.1.1 v hv

theorem deadOk_edge (hc : D.deadOk = true) {f : Fact} (hf : f ∈ D.T.edges) : D.edgeOk f = true := by
  simp only [DCert.deadOk, Bool.and_eq_true, List.all_eq_true] at hc
  exact hc.1.2 f hf

theorem deadOk_stream (hc : D.deadOk = true) {i : Nat} (hi : i < D.streams.size) :
    D.shapeOk D.streams[i]! = true ∧ D.rankOk D.streams[i]! = true := by
  simp only [DCert.deadOk, Bool.and_eq_true, Array.all_eq_true] at hc
  have := hc.2 i hi
  rw [getElem!_pos D.streams i hi]
  simpa [DCert.streamOk] using this

/-- The ranks a stream that checks keeps. -/
structure Ranks (D : DCert) (σ : DStream) : Prop where
  start_read : ∀ g ∈ σ.puts, D.πs[g.ev]! < σ.πread
  buf : σ.buffered = true → σ.πread < σ.πpush ∧ σ.πpush < σ.πpull ∧
    (∀ g ∈ σ.puts, σ.πpush < D.πf[g.ev]!) ∧
    ∀ sg ∈ σ.slots, ∀ g ∈ sg.1, D.πs[g.ev]! < σ.πpull ∧ σ.πpull < D.πf[g.ev]!
  unbuf : σ.buffered = false → σ.πread < σ.πxfer ∧ (∀ g ∈ σ.puts, σ.πxfer < D.πf[g.ev]!) ∧
    ∀ sg ∈ σ.slots, ∀ g ∈ sg.1, D.πs[g.ev]! < σ.πxfer ∧ σ.πxfer < D.πf[g.ev]!

theorem ranks_of {σ : DStream} (h : D.rankOk σ = true) : Ranks D σ := by
  simp only [DCert.rankOk, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h
  obtain ⟨h1, h2⟩ := h
  refine ⟨h1, fun hb => ?_, fun hb => ?_⟩
  · simp only [hb, ite_true, Bool.and_eq_true, decide_eq_true_eq, List.all_eq_true] at h2
    obtain ⟨⟨⟨a, b⟩, c⟩, d⟩ := h2
    exact ⟨a, b, c, fun sg hsg g hg => d sg hsg g hg⟩
  · simp only [hb, Bool.false_eq_true, ite_false, Bool.and_eq_true, decide_eq_true_eq,
      List.all_eq_true] at h2
    obtain ⟨⟨a, b⟩, d⟩ := h2
    exact ⟨a, b, fun sg hsg g hg => d sg hsg g hg⟩

/-- Everything known of an element of `p`. -/
structure EFacts (D : DCert) (p : Prog) (evOf : Nat → Nat × Iter) (elOf : Nat → Nat × Nat)
    (elIt : Nat → Iter) (k : Nat) (el : Elem) : Prop where
  real : ElemRealized D p evOf elOf elIt k el
  shape : D.shapeOk D.streams[(elOf k).1]! = true
  ranks : Ranks D D.streams[(elOf k).1]!

theorem efacts (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k : Nat} {el : Elem}
    (hk : p.elems[k]? = some el) : EFacts D p evOf elOf elIt k el := by
  have er := hr.elems k el hk
  obtain ⟨hsh, hrk⟩ := deadOk_stream hc er.stream
  exact ⟨er, hsh, ranks_of hrk⟩

theorem getElem?_of_lt {k : Nat} (h : k < p.elems.size) : ∃ e, p.elems[k]? = some e :=
  ⟨_, Array.getElem?_eq_getElem h⟩

/-- The put of an element: an event of its stream's puts, at its coordinates. -/
theorem src_facts (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k x : Nat}
    {el : Elem} (hk : p.elems[k]? = some el) (hx : el.src = some x) :
    x < p.graph.size ∧ ∀ π,
      (D.πs[(evOf x).1]! < π → keyOf D tot evOf elOf elIt (.start x) <
        D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) π) ∧
      (π < D.πf[(evOf x).1]! → D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) π <
        keyOf D tot evOf elOf elIt (.finish x)) ∧
      ∃ g ∈ D.streams[(elOf k).1]!.puts, (evOf x).1 = g.ev := by
  have F := efacts hc hr hk
  obtain ⟨x', hx', hxl, g, hg, hev, hat⟩ := F.real.src
  rw [hx] at hx'; cases hx'
  have hside := (shape_parts F.shape).2.2.1
  refine ⟨hxl, fun π => ⟨fun h => ?_, fun h => ?_, g, hg, hev⟩⟩
  · simp only [keyOf]; rw [hev] at h ⊢
    exact (seg_lt F.shape hside hg hat).1 h
  · simp only [keyOf]; rw [hev] at h ⊢
    exact (seg_lt F.shape hside hg hat).2 h

/-- A get of an element at slot `i`: an event of that slot's gets, at its coordinates. -/
theorem dst_facts (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k x i : Nat}
    {el : Elem} (hk : p.elems[k]? = some el) (hx : el.dsts[i]? = some (some x)) :
    x < p.graph.size ∧ ∃ sg, D.streams[(elOf k).1]!.slots[i]? = some sg ∧ ∀ π,
      (D.πs[(evOf x).1]! < π → keyOf D tot evOf elOf elIt (.start x) <
        D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) π) ∧
      (π < D.πf[(evOf x).1]! → D.keyEl tot D.streams[(elOf k).1]! (elOf k).2 (elIt k) π <
        keyOf D tot evOf elOf elIt (.finish x)) ∧
      ∃ g ∈ sg.1, (evOf x).1 = g.ev := by
  have F := efacts hc hr hk
  have hil : i < el.dsts.length := (List.getElem?_eq_some_iff.mp hx).1
  rw [F.real.dlen] at hil
  obtain ⟨sg, hsg⟩ : ∃ sg, D.streams[(elOf k).1]!.slots[i]? = some sg :=
    ⟨_, List.getElem?_eq_getElem hil⟩
  have hd := F.real.dsts i sg hsg
  have hne : sg.1 ≠ [] := by
    intro h; have := hd.1 h; rw [hx] at this; cases this
  obtain ⟨x', hx', hxl, g, hg, hev, hat⟩ := hd.2 hne
  rw [hx] at hx'; cases hx'
  have hside := (shape_parts F.shape).2.2.2.1 sg (List.mem_of_getElem? hsg)
  refine ⟨hxl, sg, hsg, fun π => ⟨fun h => ?_, fun h => ?_, g, hg, hev⟩⟩
  · simp only [keyOf]; rw [hev] at h ⊢
    exact (seg_lt F.shape hside hg hat).1 h
  · simp only [keyOf]; rw [hev] at h ⊢
    exact (seg_lt F.shape hside hg hat).2 h

/-- Slot `i` of an element is got iff that of every element of its stream is. -/
theorem got_iff (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k j i : Nat}
    {el ej : Elem} (hk : p.elems[k]? = some el) (hj : p.elems[j]? = some ej)
    (hs : (elOf j).1 = (elOf k).1) (h : ∃ d, el.dsts[i]? = some (some d)) :
    ∃ d, ej.dsts[i]? = some (some d) := by
  have F := efacts hc hr hk
  have Fj := efacts hc hr hj
  obtain ⟨d, hd⟩ := h
  have hil : i < el.dsts.length := (List.getElem?_eq_some_iff.mp hd).1
  rw [F.real.dlen] at hil
  obtain ⟨sg, hsg⟩ : ∃ sg, D.streams[(elOf k).1]!.slots[i]? = some sg :=
    ⟨_, List.getElem?_eq_getElem hil⟩
  have hne : sg.1 ≠ [] := by
    intro h; have := (F.real.dsts i sg hsg).1 h; rw [hd] at this; cases this
  have hsg' : D.streams[(elOf j).1]!.slots[i]? = some sg := by rw [hs]; exact hsg
  obtain ⟨x, hx, _⟩ := (Fj.real.dsts i sg hsg').2 hne
  exact ⟨x, hx⟩

/-! ### Each kind of label: what it waits for is in, and ranks lower -/

theorem pre_start (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {x : Nat}
    (hx : x < p.graph.size) {z : Chan.Label} (hz : z ∈ hbPreds p (.start x)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.start x) := by
  simp only [hbPreds, List.mem_map] at hz
  obtain ⟨u, hu, rfl⟩ := hz
  obtain ⟨hus, f, hf, hsrc, hdst, hm⟩ := hr.preds x hx u hu
  refine ⟨mem_all_finish.mpr hus, ?_⟩
  obtain ⟨hvu, hValu⟩ := hr.ev u hus
  obtain ⟨hvx, hValx⟩ := hr.ev x hx
  simp only [keyOf]
  rw [← hsrc, ← hdst]
  rw [← hsrc] at hValu hvu
  rw [← hdst] at hValx hvx
  exact edge_lt hr.aligned (deadOk_edge hc hf) (deadOk_ev hc hvu) (deadOk_ev hc hvx) hValu hValx hm

theorem sentLabel_of {k : Nat} {el : Elem} (hk : p.elems[k]? = some el) :
    sentLabel p k = if el.buffered then .push k else .xfer k := by
  simp [sentLabel, hk]

theorem gotLabel_of {k i : Nat} {el : Elem} (hk : p.elems[k]? = some el) :
    gotLabel p k i = if el.buffered then .pull k i else .xfer k := by
  simp [gotLabel, hk]

theorem pre_finish (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {x : Nat}
    (hx : x < p.graph.size) {z : Chan.Label} (hz : z ∈ hbPreds p (.finish x)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.finish x) := by
  simp only [hbPreds, List.mem_cons, List.mem_flatMap, List.mem_range] at hz
  rcases hz with rfl | ⟨k, _, hz⟩
  · exact ⟨mem_all_start.mpr hx, by simp only [keyOf]; exact ev_lt (deadOk_ev hc (hr.ev x hx).1)⟩
  · cases hel : p.elems[k]? with
    | none => simp [hel] at hz
    | some el =>
      rw [hel] at hz
      simp only [List.mem_append, List.mem_filterMap, List.mem_range] at hz
      have F := efacts hc hr hel
      rcases hz with hz | ⟨i, hi, hz⟩
      · split at hz
        · next hsx =>
          simp only [List.mem_singleton] at hz; subst hz
          obtain ⟨_, hk⟩ := src_facts hc hr hel hsx
          obtain ⟨g, hg, hev⟩ := (hk 0).2.2
          rw [sentLabel_of hel]
          cases hb : el.buffered
          · have rk := F.ranks.unbuf (by rw [← F.real.buffered]; exact hb)
            refine ⟨mem_all_xfer.mpr ⟨el, hel, hb⟩, ?_⟩
            simp only [Bool.false_eq_true, ite_false, keyOf]
            exact (hk _).2.1 (by rw [hev]; exact rk.2.1 g hg)
          · have rk := F.ranks.buf (by rw [← F.real.buffered]; exact hb)
            refine ⟨mem_all_push.mpr ⟨el, hel, hb⟩, ?_⟩
            simp only [ite_true, keyOf]
            exact (hk _).2.1 (by rw [hev]; exact rk.2.2.1 g hg)
        · simp at hz
      · split at hz
        · next hdx =>
          simp only [Option.some.injEq] at hz; subst hz
          obtain ⟨_, sg, hsg, hk⟩ := dst_facts hc hr hel hdx
          obtain ⟨g, hg, hev⟩ := ((hk 0).2.2)
          have hsgm := List.mem_of_getElem? hsg
          rw [gotLabel_of hel]
          cases hb : el.buffered
          · have rk := F.ranks.unbuf (by rw [← F.real.buffered]; exact hb)
            refine ⟨mem_all_xfer.mpr ⟨el, hel, hb⟩, ?_⟩
            simp only [Bool.false_eq_true, ite_false, keyOf]
            exact (hk _).2.1 (by rw [hev]; exact (rk.2.2 sg hsgm g hg).2)
          · have rk := F.ranks.buf (by rw [← F.real.buffered]; exact hb)
            refine ⟨mem_all_pull.mpr ⟨el, hel, hb, x, hdx⟩, ?_⟩
            simp only [ite_true, keyOf]
            exact (hk _).2.1 (by rw [hev]; exact (rk.2.2.2 sg hsgm g hg).2)
        · simp at hz

/-- The previous element: in, of the same stream, one index lower. -/
theorem prev_facts (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k j : Nat}
    {el : Elem} (hk : p.elems[k]? = some el) (hj : el.prev = some j) :
    ∃ ej, p.elems[j]? = some ej ∧ ej.buffered = el.buffered ∧
      (elOf j).1 = (elOf k).1 ∧ (elOf j).2 + 1 = (elOf k).2 ∧
      (D.streams[(elOf k).1]!.isLocal = true → elIt j = elIt k) := by
  have F := efacts hc hr hk
  obtain ⟨hjs, h1, h2, h3⟩ := F.real.prev j hj
  obtain ⟨ej, hej⟩ := getElem?_of_lt hjs
  have Fj := efacts hc hr hej
  exact ⟨ej, hej, by rw [Fj.real.buffered, F.real.buffered, h1], h1, h2, h3⟩

theorem pre_read (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k : Nat}
    (hl : Label.read k ∈ allLabels p) {z : Chan.Label} (hz : z ∈ hbPreds p (.read k)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.read k) := by
  obtain ⟨el, hel⟩ := mem_all_read.mp hl
  have F := efacts hc hr hel
  simp only [hbPreds, hel, List.mem_append] at hz
  rcases hz with hz | hz
  · obtain ⟨s, hs, rfl⟩ := mem_optL hz
    obtain ⟨hxl, hk⟩ := src_facts hc hr hel hs
    obtain ⟨g, hg, hev⟩ := (hk 0).2.2
    refine ⟨mem_all_start.mpr hxl, ?_⟩
    simp only [keyOf] at hk ⊢
    exact (hk _).1 (by rw [hev]; exact F.ranks.start_read g hg)
  · obtain ⟨j, hj, rfl⟩ := mem_optL hz
    obtain ⟨ej, hej, _, h1, h2, h3⟩ := prev_facts hc hr hel hj
    refine ⟨mem_all_read.mpr ⟨ej, hej⟩, ?_⟩
    simp only [keyOf]
    rw [h1]
    exact el_lt_el (by omega) h3 (Or.inr ⟨rfl, by omega⟩)

theorem pre_push (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k : Nat}
    (hl : Label.push k ∈ allLabels p) {z : Chan.Label} (hz : z ∈ hbPreds p (.push k)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.push k) := by
  obtain ⟨el, hel, hb⟩ := mem_all_push.mp hl
  have F := efacts hc hr hel
  have rk := F.ranks.buf (by rw [← F.real.buffered]; exact hb)
  simp only [hbPreds, hel, List.mem_cons] at hz
  rcases hz with rfl | hz
  · refine ⟨mem_all_read.mpr ⟨el, hel⟩, ?_⟩
    simp only [keyOf]
    exact el_lt_el (Nat.le_refl _) (fun _ => rfl) (Or.inl rk.1)
  · obtain ⟨j, hj, rfl⟩ := mem_optL hz
    obtain ⟨ej, hej, hbj, h1, h2, h3⟩ := prev_facts hc hr hel hj
    rw [sentLabel_of hej, hbj, hb]
    refine ⟨mem_all_push.mpr ⟨ej, hej, by rw [hbj, hb]⟩, ?_⟩
    simp only [ite_true, keyOf]
    rw [h1]
    exact el_lt_el (by omega) h3 (Or.inr ⟨rfl, by omega⟩)

theorem pre_pull (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k i : Nat}
    (hl : Label.pull k i ∈ allLabels p) {z : Chan.Label} (hz : z ∈ hbPreds p (.pull k i)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.pull k i) := by
  obtain ⟨el, hel, hb, hgot⟩ := mem_all_pull.mp hl
  have F := efacts hc hr hel
  have rk := F.ranks.buf (by rw [← F.real.buffered]; exact hb)
  simp only [hbPreds, hel, List.mem_cons, List.mem_append] at hz
  rcases hz with (rfl | hz) | hz
  · refine ⟨mem_all_push.mpr ⟨el, hel, hb⟩, ?_⟩
    simp only [keyOf]
    exact el_lt_el (Nat.le_refl _) (fun _ => rfl) (Or.inl rk.2.1)
  · split at hz
    · next d hd =>
      simp only [List.mem_singleton] at hz; subst hz
      obtain ⟨hxl, sg, hsg, hk⟩ := dst_facts hc hr hel hd
      obtain ⟨g, hg, hev⟩ := (hk 0).2.2
      refine ⟨mem_all_start.mpr hxl, ?_⟩
      exact (hk _).1 (by rw [hev]; exact (rk.2.2.2 sg (List.mem_of_getElem? hsg) g hg).1)
    · simp at hz
  · obtain ⟨j, hj, rfl⟩ := mem_optL hz
    obtain ⟨ej, hej, hbj, h1, h2, h3⟩ := prev_facts hc hr hel hj
    rw [gotLabel_of hej, hbj, hb]
    obtain ⟨d', hd'⟩ := got_iff hc hr hel hej h1 hgot
    refine ⟨mem_all_pull.mpr ⟨ej, hej, by rw [hbj, hb], d', hd'⟩, ?_⟩
    simp only [ite_true, keyOf]
    rw [h1]
    exact el_lt_el (by omega) h3 (Or.inr ⟨rfl, by omega⟩)

theorem pre_xfer (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {k : Nat}
    (hl : Label.xfer k ∈ allLabels p) {z : Chan.Label} (hz : z ∈ hbPreds p (.xfer k)) :
    z ∈ allLabels p ∧ keyOf D tot evOf elOf elIt z < keyOf D tot evOf elOf elIt (.xfer k) := by
  obtain ⟨el, hel, hb⟩ := mem_all_xfer.mp hl
  have F := efacts hc hr hel
  have rk := F.ranks.unbuf (by rw [← F.real.buffered]; exact hb)
  simp only [hbPreds, hel, List.mem_cons, List.mem_append] at hz
  rcases hz with (rfl | hz) | hz
  · refine ⟨mem_all_read.mpr ⟨el, hel⟩, ?_⟩
    simp only [keyOf]
    exact el_lt_el (Nat.le_refl _) (fun _ => rfl) (Or.inl rk.1)
  · simp only [List.mem_map, List.mem_filterMap, id] at hz
    obtain ⟨d, ⟨o, ho, hod⟩, rfl⟩ := hz
    subst hod
    obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp ho
    obtain ⟨hxl, sg, hsg, hk⟩ := dst_facts hc hr hel hi
    obtain ⟨g, hg, hev⟩ := (hk 0).2.2
    refine ⟨mem_all_start.mpr hxl, ?_⟩
    exact (hk _).1 (by rw [hev]; exact (rk.2.2 sg (List.mem_of_getElem? hsg) g hg).1)
  · split at hz
    · next j hj =>
      simp only [List.mem_map, List.mem_range] at hz
      obtain ⟨i, _, rfl⟩ := hz
      obtain ⟨ej, hej, hbj, h1, h2, h3⟩ := prev_facts hc hr hel hj
      rw [gotLabel_of hej, hbj, hb]
      refine ⟨mem_all_xfer.mpr ⟨ej, hej, by rw [hbj, hb]⟩, ?_⟩
      simp only [Bool.false_eq_true, ite_false, keyOf]
      rw [h1]
      exact el_lt_el (by omega) h3 (Or.inr ⟨rfl, by omega⟩)
    · simp at hz

/-- Every label of `p` is enabled once all have fired. -/
theorem en_all (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) {l : Chan.Label}
    (hl : l ∈ allLabels p) : En p (allLabels p) l := by
  cases l with
  | start v =>
    have hv := mem_all_start.mp hl
    exact ⟨hv, fun u hu => mem_all_finish.mpr (hr.preds v hv u hu).1⟩
  | finish v =>
    have hv := mem_all_finish.mp hl
    refine ⟨hv, mem_all_start.mpr hv, fun k e he => ⟨fun _ => ?_, fun i hi => ?_⟩⟩
    · cases hb : e.buffered
      · exact Or.inr (mem_all_xfer.mpr ⟨e, he, hb⟩)
      · exact Or.inl (mem_all_push.mpr ⟨e, he, hb⟩)
    · cases hb : e.buffered
      · exact Or.inr (mem_all_xfer.mpr ⟨e, he, hb⟩)
      · exact Or.inl (mem_all_pull.mpr ⟨e, he, hb, v, hi⟩)
  | read k =>
    obtain ⟨el, hel⟩ := mem_all_read.mp hl
    have F := efacts hc hr hel
    obtain ⟨xs, hxs, hxl, _⟩ := F.real.src
    refine ⟨el, hel, ⟨xs, hxs, mem_all_start.mpr hxl⟩, fun j hj => ?_⟩
    obtain ⟨ej, hej, _⟩ := prev_facts hc hr hel hj
    exact mem_all_read.mpr ⟨ej, hej⟩
  | push k =>
    obtain ⟨el, hel, hb⟩ := mem_all_push.mp hl
    refine ⟨el, hel, hb, mem_all_read.mpr ⟨el, hel⟩, fun j hj => ?_⟩
    obtain ⟨ej, hej, hbj, _⟩ := prev_facts hc hr hel hj
    exact Or.inl (mem_all_push.mpr ⟨ej, hej, by rw [hbj, hb]⟩)
  | pull k i =>
    obtain ⟨el, hel, hb, d, hd⟩ := mem_all_pull.mp hl
    have hxl := (dst_facts hc hr hel hd).1
    refine ⟨el, hel, hb, ⟨d, hd, mem_all_start.mpr hxl⟩, mem_all_push.mpr ⟨el, hel, hb⟩,
      fun j hj => ?_⟩
    obtain ⟨ej, hej, hbj, h1, _⟩ := prev_facts hc hr hel hj
    obtain ⟨d', hd'⟩ := got_iff hc hr hel hej h1 ⟨d, hd⟩
    exact Or.inl (mem_all_pull.mpr ⟨ej, hej, by rw [hbj, hb], d', hd'⟩)
  | xfer k =>
    obtain ⟨el, hel, hb⟩ := mem_all_xfer.mp hl
    have F := efacts hc hr hel
    obtain ⟨hne, hall⟩ := (shape_parts F.shape).2.2.2.2 (by rw [← F.real.buffered]; exact hb)
    refine ⟨el, hel, hb, mem_all_read.mpr ⟨el, hel⟩, ⟨?_, fun o ho => ?_⟩, fun j hj i _ => ?_⟩
    · intro h
      have := F.real.dlen
      rw [h] at this
      exact hne (List.length_eq_zero_iff.mp this.symm)
    · obtain ⟨i, hi⟩ := List.mem_iff_getElem?.mp ho
      have hil : i < el.dsts.length := (List.getElem?_eq_some_iff.mp hi).1
      rw [F.real.dlen] at hil
      obtain ⟨sg, hsg⟩ : ∃ sg, D.streams[(elOf k).1]!.slots[i]? = some sg :=
        ⟨_, List.getElem?_eq_getElem hil⟩
      obtain ⟨x, hx, hxl, _⟩ := (F.real.dsts i sg hsg).2 (hall sg (List.mem_of_getElem? hsg))
      rw [hx] at hi; cases hi
      exact ⟨x, rfl, mem_all_start.mpr hxl⟩
    · obtain ⟨ej, hej, hbj, _⟩ := prev_facts hc hr hel hj
      exact Or.inr (mem_all_xfer.mpr ⟨ej, hej, by rw [hbj, hb]⟩)

/-- **Completion for every trip count**: when the certificate checks, every program realizing it
(for any trip counts `n` its classes align) has a complete execution. -/
theorem completes_of_deadOk (hc : D.deadOk = true) (hr : RealizesD D n tot p evOf elOf elIt) :
    ∃ t G, Run p [] t G ∧ Done p G :=
  completes_of_rank' (allLabels p) (keyOf D tot evOf elOf elIt) (fun _ hl => en_all hc hr hl)
    (fun l hl z hz => by
      cases l with
      | start x => exact pre_start hc hr (mem_all_start.mp hl) hz
      | finish x => exact pre_finish hc hr (mem_all_finish.mp hl) hz
      | read k => exact pre_read hc hr hl hz
      | push k => exact pre_push hc hr hl hz
      | pull k i => exact pre_pull hc hr hl hz
      | xfer k => exact pre_xfer hc hr hl hz)
    (fun _ hv => mem_all_finish.mpr hv)

/-- **One outcome for every trip count**: with phase 2a's certificate (race-freedom) and phase 2b's
(completion), for any trip counts, a complete execution exists and every complete execution ends
with its memory. -/
theorem outcome_every_trip {V : Type} {T : Template} {fp : Chan.LFp}
    {eff : Chan.Label → Veir.Air.Mem V → Veir.Air.Mem V}
    {num : Nat → Iter → Nat} {loc : Nat → Iter → Int → Nat × Int} {exempt : Nat → Prop}
    (hc : T.certOk = true) (hd : D.deadOk = true)
    (hr : Realizes T n p fp num loc exempt fun _ => True) (hrd : RealizesD D n tot p evOf elOf elIt)
    (hw : Chan.WF p) (hfr : Chan.LFramed fp eff) :
    ∃ t G, Run p [] t G ∧ Done p G ∧
      ∀ t' G', Run p [] t' G' → Done p G' → ∀ m, Chan.runL eff t' m = Chan.runL eff t m := by
  obtain ⟨t, G, r, d⟩ := completes_of_deadOk hd hrd
  have hrf := raceFree_of_certOk hc hr
  exact ⟨t, G, r, d, fun t' G' r' d' m =>
    (Chan.deterministic hw hfr r d r' d' (fun x y _ _ => hrf x y trivial trivial) m).symm⟩

end

end LoopDead

end

end Veir.Air
