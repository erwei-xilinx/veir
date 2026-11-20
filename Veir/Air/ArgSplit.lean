module

public import Veir.Air.Instance
-- `IntPred.eval`'s body, for `eval_invariant`.
import all Veir.Data.LLVM.Int.Basic

namespace Veir.Air.ArgSplit

@[expose] public section

/-! # Branches on scalar arguments: every value, by finitely many

A function whose control flow branches on a scalar argument not given (`--args`) cannot be
instantiated: which region runs is not known. When the argument decides only *comparisons with
constants*, finitely many values cover all of them: the constants themselves, and one value in each
gap between them. Instantiating with each such value, and checking each program, gives the verdicts
for every value of the argument.

Proven here:
* `reps_cover`: for every `x` in `[lo, hi]` some value `r` of `reps C lo hi` compares with every
  constant of `C` as `x` does (`<` and `=`; `r = x` when `x` is a constant);
* `eval_invariant`, `eval_invariant'`: then every signed or equality predicate of VeIR's `arith.cmpi`
  (`IntPred.eval`) gives the same result on `r` as on `x`, with the argument on either side;
* `combos_cover`: with several arguments, every tuple of values is covered by some tuple of the
  product of their `reps`.

Trusted (extraction, `plan` below, as `Instance` is): that the argument reaches the program only
through such comparisons with constants (`arith.cmpi` with `eq`, `ne`, `slt`, `sle`, `sgt`, `sge`,
and `scf.index_switch`'s cases), through the `args` of launch, segment and herd and casts that
sign-extend; so that the programs instantiated with `x` and with `r` are the same. An `i1` argument
is tried with both values, whatever reads it.
-/

/-! ### Proven: finitely many values cover every value -/

/-- The constants of `C` in the range `[lo, hi]`. -/
def inRange (C : List Int) (lo hi : Int) : List Int :=
  C.filter fun c => decide (lo ≤ c) && decide (c ≤ hi)

/-- The values tried for an argument with range `[lo, hi]` compared with the constants `C`: each
constant in the range, each such constant plus one (the gap above it), and one less than the
smallest (the gap below all of them; `hi` when there is none). -/
def reps (C : List Int) (lo hi : Int) : List Int :=
  inRange C lo hi ++ ((inRange C lo hi).map (· + 1)).filter (fun c => decide (c ≤ hi)) ++
    [(inRange C lo hi).foldl min (hi + 1) - 1]

/-- The largest constant below `x`, or `m0` when it is larger. -/
def below (C : List Int) (x m0 : Int) : Int :=
  C.foldl (fun m c => if c < x then max m c else m) m0

/-- One step of `below`. -/
theorem below_step (x m0 c : Int) :
    let m1 := if c < x then max m0 c else m0
    m0 ≤ m1 ∧ (m0 < x → m1 < x) ∧ (c < x → c ≤ m1) ∧ (m1 = m0 ∨ m1 = c) := by
  simp only [Int.max_def]
  split <;> (try split) <;> omega

theorem below_props (C : List Int) (x : Int) : ∀ m0 : Int,
    m0 ≤ below C x m0 ∧ (m0 < x → below C x m0 < x) ∧ (∀ c ∈ C, c < x → c ≤ below C x m0) ∧
    (below C x m0 = m0 ∨ below C x m0 ∈ C) := by
  induction C with
  | nil => intro m0; simp [below]
  | cons c cs ih =>
    intro m0
    have h := ih (if c < x then max m0 c else m0)
    obtain ⟨s1, s2, s3, s4⟩ := below_step x m0 c
    simp only [below, List.foldl_cons] at h ⊢
    generalize (if c < x then max m0 c else m0) = m1 at h s1 s2 s3 s4
    obtain ⟨h1, h2, h3, h4⟩ := h
    refine ⟨by omega, fun hx => h2 (s2 hx), ?_, ?_⟩
    · intro c' hc' hlt
      rcases List.mem_cons.mp hc' with rfl | hc'
      · have := s3 hlt; omega
      · exact h3 c' hc' hlt
    · rcases h4 with h4 | h4
      · rw [h4]; rcases s4 with s4 | s4
        · exact Or.inl s4
        · exact Or.inr (s4 ▸ List.mem_cons_self ..)
      · exact Or.inr (List.mem_cons_of_mem _ h4)

theorem foldl_min_props (D : List Int) : ∀ m0 : Int,
    D.foldl min m0 ≤ m0 ∧ (∀ d ∈ D, D.foldl min m0 ≤ d) ∧ (D.foldl min m0 = m0 ∨ D.foldl min m0 ∈ D) := by
  induction D with
  | nil => intro m0; simp
  | cons d ds ih =>
    intro m0
    obtain ⟨h1, h2, h3⟩ := ih (min m0 d)
    simp only [List.foldl_cons]
    refine ⟨by omega, ?_, ?_⟩
    · intro d' hd'
      rcases List.mem_cons.mp hd' with rfl | hd'
      · omega
      · exact h2 d' hd'
    · rcases h3 with h3 | h3
      · rw [h3]; rcases Int.le_total m0 d with hm | hm
        · rw [Int.min_eq_left hm]; exact Or.inl rfl
        · rw [Int.min_eq_right hm]; exact Or.inr (List.mem_cons_self ..)
      · exact Or.inr (List.mem_cons_of_mem _ h3)

theorem mem_inRange {C : List Int} {lo hi c : Int} :
    c ∈ inRange C lo hi ↔ c ∈ C ∧ lo ≤ c ∧ c ≤ hi := by
  simp [inRange]

theorem reps_cover (C : List Int) (lo hi x : Int) (h1 : lo ≤ x) (h2 : x ≤ hi) :
    ∃ r ∈ reps C lo hi, (x ∈ C → r = x) ∧ ∀ c ∈ C, (x < c ↔ r < c) ∧ (x = c ↔ r = c) := by
  simp only [reps, List.mem_append, List.mem_filter, List.mem_map, List.mem_singleton,
    decide_eq_true_eq]
  by_cases hx : x ∈ C
  · exact ⟨x, Or.inl (Or.inl (mem_inRange.mpr ⟨hx, h1, h2⟩)), fun _ => rfl,
      fun c _ => ⟨Iff.rfl, Iff.rfl⟩⟩
  have hne : ∀ c ∈ C, x ≠ c := fun c hc h => hx (h ▸ hc)
  obtain ⟨b1, b2, b3, b4⟩ := below_props C x (lo - 1)
  have hb : below C x (lo - 1) < x := b2 (by omega)
  by_cases hlo : lo ≤ below C x (lo - 1)
  · -- The gap above the largest constant below `x`.
    have bC : below C x (lo - 1) ∈ C := by
      rcases b4 with b4 | b4
      · omega
      · exact b4
    refine ⟨below C x (lo - 1) + 1, Or.inl (Or.inr ⟨⟨_, mem_inRange.mpr ⟨bC, hlo, by omega⟩, rfl⟩,
      by omega⟩), fun h => absurd h hx, ?_⟩
    intro c hc
    rcases Int.lt_or_gt_of_ne (hne c hc) with h | h
    · exact ⟨⟨fun _ => by omega, fun _ => h⟩, ⟨fun e => absurd e (hne c hc), fun _ => by omega⟩⟩
    · have := b3 c hc h
      exact ⟨⟨fun _ => by omega, fun _ => by omega⟩, ⟨fun e => absurd e (hne c hc), fun _ => by omega⟩⟩
  · -- No constant in `[lo, x)`: the gap below the smallest constant in the range.
    obtain ⟨t1, t2, t3⟩ := foldl_min_props (inRange C lo hi) (hi + 1)
    generalize (inRange C lo hi).foldl min (hi + 1) = t at t1 t2 t3 ⊢
    have ht : x < t := by
      rcases t3 with t3 | t3
      · omega
      · obtain ⟨tC, tlo, _⟩ := mem_inRange.mp t3
        rcases Int.lt_or_gt_of_ne (hne t tC) with h | h
        · exact h
        · have := b3 t tC h; omega
    refine ⟨t - 1, Or.inr rfl, fun h => absurd h hx, ?_⟩
    intro c hc
    rcases Int.lt_or_gt_of_ne (hne c hc) with h | h
    · by_cases chi : c ≤ hi
      · have := t2 c (mem_inRange.mpr ⟨hc, by omega, chi⟩)
        exact ⟨⟨fun _ => by omega, fun _ => h⟩, ⟨fun e => absurd e (hne c hc), fun _ => by omega⟩⟩
      · exact ⟨⟨fun _ => by omega, fun _ => h⟩, ⟨fun e => absurd e (hne c hc), fun _ => by omega⟩⟩
    · have := b3 c hc h
      exact ⟨⟨fun _ => by omega, fun _ => by omega⟩, ⟨fun e => absurd e (hne c hc), fun _ => by omega⟩⟩

/-- The predicates of `arith.cmpi` that compare signed values or test equality. -/
def signedPred : Data.LLVM.IntPred → Bool
  | .eq | .ne | .sgt | .sge | .slt | .sle => true
  | _ => false

theorem eval_invariant {w : Nat} (p : Data.LLVM.IntPred) (hp : signedPred p = true)
    (x r y : BitVec w) (hlt : x.toInt < y.toInt ↔ r.toInt < y.toInt)
    (heq : x.toInt = y.toInt ↔ r.toInt = y.toInt) :
    p.eval x y = p.eval r y := by
  have e1 : (x == y) = (r == y) := by
    have h : x = y ↔ r = y := by simpa only [BitVec.toInt_inj] using heq
    rw [Bool.eq_iff_iff]; simpa only [beq_iff_eq] using h
  cases p <;> (try simp [signedPred] at hp) <;>
    simp only [Data.LLVM.IntPred.eval, bne, e1, BitVec.slt, BitVec.sle, decide_eq_decide]
  all_goals
    rcases Int.lt_trichotomy x.toInt y.toInt with h | h | h
    · have := hlt.mp h; constructor <;> intro <;> omega
    · have := heq.mp h; constructor <;> intro <;> omega
    · have h3 : ¬ r.toInt < y.toInt := fun h' => by have := hlt.mpr h'; omega
      have h4 : r.toInt ≠ y.toInt := fun h' => by have := heq.mpr h'; omega
      constructor <;> intro <;> omega

theorem eval_invariant' {w : Nat} (p : Data.LLVM.IntPred) (hp : signedPred p = true)
    (x r y : BitVec w) (hlt : x.toInt < y.toInt ↔ r.toInt < y.toInt)
    (heq : x.toInt = y.toInt ↔ r.toInt = y.toInt) :
    p.eval y x = p.eval y r := by
  have e1 : (y == x) = (y == r) := by
    have h : x = y ↔ r = y := by simpa only [BitVec.toInt_inj] using heq
    rw [Bool.eq_iff_iff]; simp only [beq_iff_eq]; constructor
    · intro e; exact (h.mp e.symm).symm
    · intro e; exact (h.mpr e.symm).symm
  cases p <;> (try simp [signedPred] at hp) <;>
    simp only [Data.LLVM.IntPred.eval, bne, e1, BitVec.slt, BitVec.sle, decide_eq_decide]
  all_goals
    rcases Int.lt_trichotomy x.toInt y.toInt with h | h | h
    · have := hlt.mp h; constructor <;> intro <;> omega
    · have := heq.mp h; constructor <;> intro <;> omega
    · have h3 : ¬ r.toInt < y.toInt := fun h' => by have := hlt.mpr h'; omega
      have h4 : r.toInt ≠ y.toInt := fun h' => by have := heq.mpr h'; omega
      constructor <;> intro <;> omega

/-- Every tuple with one value from each list. -/
def combos : List (List Int) → List (List Int)
  | [] => [[]]
  | l :: ls => l.flatMap fun a => (combos ls).map (a :: ·)

theorem combos_cover : ∀ (ls : List (List Int)) (xs : List Int), xs.length = ls.length →
    (∀ i (h : i < xs.length) (h' : i < ls.length), xs[i] ∈ ls[i]) → xs ∈ combos ls
  | [], [], _, _ => by simp [combos]
  | l :: ls, x :: xs, hl, h => by
    simp only [combos, List.mem_flatMap, List.mem_map]
    refine ⟨x, h 0 (by simp) (by simp), xs, combos_cover ls xs (by simpa using hl) ?_, rfl⟩
    intro i hi hi'
    exact h (i + 1) (by simpa using hi) (by simpa using hi')
  | [], _ :: _, hl, _ => by simp at hl
  | _ :: _, [], hl, _ => by simp at hl

/-! ### Trusted: which arguments are split, and the values tried -/

/-- A scalar argument split into classes by the comparisons that read it. -/
structure Split where
  /-- Its position among the scalar arguments, as `--args` counts them. -/
  pos : Nat
  /-- Its position among the function's arguments. -/
  arg : Nat
  /-- The constants it is compared with (for `i1`, both values). -/
  consts : List Int
  /-- The values tried, `reps consts lo hi` for its range `[lo, hi]`. -/
  values : List Int

/-- The bit width of an integer or `index` value. -/
def widthOf (ctx : IRContext OpCode) (v : ValuePtr) : Option Nat :=
  match typeString (v.getType! ctx) with
  | "index" => some 64
  | t => match t.toList with
    | 'i' :: ds => (String.ofList ds).toNat?
    | _ => none

/-- The value of `v` when constants and casts of constants define it, as `arith.cmpi` compares it
(signed, at its width). -/
partial def hostConst (ctx : IRContext OpCode) (v : ValuePtr) : Option Int := do
  let .opResult ⟨op, _⟩ := v | none
  let name := opName ctx op
  let ins := op.getOperands! ctx
  let env ← if name == "arith.constant" && ins.size == 0 then some {}
    else if castOps.contains name && ins.size == 1 then do
      let c ← hostConst ctx ins[0]!
      some (({} : Std.HashMap ValuePtr HVal).insert ins[0]! (.val (intVal ctx ins[0]! c)))
    else none
  let out ← (evalHostArith ctx op env).toOption
  out[v]? >>= knownIntH?

/-- The casts that keep a value: sign extension to a width at least as large. -/
def keepsValue (ctx : IRContext OpCode) (op : OperationPtr) (v : ValuePtr) : Bool :=
  let name := opName ctx op
  (name == "arith.index_cast" || name == "arith.extsi") && op.getNumResults! ctx == 1 &&
    match widthOf ctx v, widthOf ctx (.opResult ⟨op, 0⟩) with
    | some a, some b => a ≤ b
    | _, _ => false

/-- The values that carry argument `a` unchanged: `a`, the block arguments of launch, segment and
herd it is passed to, and its sign extensions. A value that sizes a hierarchy op is refused. -/
def carriers (ctx : IRContext OpCode) (ops : Array OperationPtr) (a : ValuePtr) :
    Except String (Std.HashSet ValuePtr) := do
  let mut carry : Std.HashSet ValuePtr := ({} : Std.HashSet ValuePtr).insert a
  for _ in [0:ops.size + 1] do
    let before := carry.size
    for op in ops do
      let name := opName ctx op
      let operands := op.getOperands! ctx
      for j in [0:operands.size] do
        let v := operands[j]!
        if !carry.contains v then continue
        if keepsValue ctx op v then carry := carry.insert (.opResult ⟨op, 0⟩)
        else if hierarchyOps.contains name then
          let some seg := denseInts (findProp (unregProps ctx op) "operandSegmentSizes")
            | throw s!"'{name}': missing operandSegmentSizes"
          let isRank := name == "air.rank"
          let nDeps := seg[0]!.toNat
          let nUni := if isRank then seg[1]!.toNat else 0
          let nSizes := seg[if isRank then 2 else 1]!.toNat
          let base := nDeps + nUni + nSizes
          if j < base then throw s!"it sizes '{name}'"
          let some blk := (op.getRegion! ctx 0).getFirstBlock! ctx | throw s!"'{name}' has no body"
          let some b := (blk.getArguments! ctx)[2 * nSizes + (j - base)]?
            | throw s!"'{name}': an argument without a block argument"
          carry := carry.insert b
    if carry.size == before then break
  return carry

/-- What reads argument `a` (other than the carriers): whether anything does, and the constants
it is compared with. Anything but a comparison with a constant (signed or equality) or an
`scf.index_switch` on it is refused. -/
def readsOf (ctx : IRContext OpCode) (ops : Array OperationPtr) (a : ValuePtr) :
    Except String (Bool × List Int) := do
  let carry ← carriers ctx ops a
  let mut used := false
  let mut consts : List Int := []
  for op in ops do
    let name := opName ctx op
    let operands := op.getOperands! ctx
    for j in [0:operands.size] do
      let v := operands[j]!
      if !carry.contains v then continue
      used := true
      if keepsValue ctx op v || hierarchyOps.contains name then continue
      if name == "arith.cmpi" && operands.size == 2 then
        let .arith .cmpi := op.getOpType! ctx | throw "'arith.cmpi' is not registered"
        let pred := (op.getProperties! ctx (OpCode.arith .cmpi)).predicate
        if !signedPred pred then throw s!"an unsigned comparison ({repr pred}) reads it"
        let other := operands[1 - j]!
        if carry.contains other then throw "'arith.cmpi' compares it with itself"
        let some c := hostConst ctx other
          | throw "'arith.cmpi' compares it with a value that is not a constant"
        consts := c :: consts
      else if name == "scf.index_switch" && j == 0 then
        consts := (denseInts (findProp (unregProps ctx op) "cases")).getD #[] |>.toList |>.append consts
      else throw s!"'{name}' reads it"
  return (used, consts)

/-- At most this many tuples of values are tried. -/
def maxTuples : Nat := 64

/-- The scalar arguments not given (`none` in `known`, or past its end) that a branch reads, and
the values tried for each; with, for each such argument not split, why. An `i1` argument read by
anything is tried with both values. -/
def plan (ctx : IRContext OpCode) (func : OperationPtr) (known : List (Option Int)) :
    Except String (List Split × List String) := do
  let block ← singleBlock ctx func "func.func"
  let ops := nestedOps ctx func
  let mut splits : List Split := []
  let mut notes : List String := []
  let mut pos := 0
  for v in block.getArguments! ctx, i in [0:block.getNumArguments! ctx] do
    let t := v.getType! ctx
    if Air.isAsyncToken t.val || isMemRefType t then continue
    let p := pos
    pos := pos + 1
    if (known[p]?.join).isSome then continue
    let some w := widthOf ctx v | continue
    if w == 0 then continue
    let lo : Int := -(2 ^ (w - 1) : Nat)
    let hi : Int := (2 ^ (w - 1) : Nat) - 1
    if w == 1 then
      if ops.any fun op => (op.getOperands! ctx).contains v then
        splits := splits ++ [{ pos := p, arg := i, consts := [lo, hi], values := [lo, hi] }]
      continue
    match readsOf ctx ops v with
    | .error e => notes := notes ++ [s!"%arg{i}: {e}"]
    | .ok (_, []) => pure ()
    | .ok (_, consts) =>
      splits := splits ++ [{ pos := p, arg := i, consts, values := (reps consts lo hi).eraseDups }]
  return (splits, notes)

/-! ### Trusted: transfer sizes from arguments, tried with sample values

A size decides how many elements a transfer moves, and so how the streams balance: there is no
finite cover of its values here. The values below are tried, each verdict proven for its value;
a value not clean refutes "for every value", and otherwise only the values tried are checked. Sizes
are positive (decided 2026-11-20). -/

/-- The values tried for an argument that decides a transfer's size. -/
def sizeSamples : List Int := [1, 2, 3]

/-- The scalar arguments not given and not split that carry, unchanged, into the sizes of an
`air.channel.put` or `air.channel.get`, or of a `memref.alloc` (D69): its position among the scalar
arguments, and among the function's arguments. -/
def sizeArgs (ctx : IRContext OpCode) (func : OperationPtr) (known : List (Option Int))
    (splits : List Split) : Except String (List (Nat × Nat)) := do
  let block ← singleBlock ctx func "func.func"
  let ops := nestedOps ctx func
  -- The size operands of every channel op (operand group 4: dependencies, indices, memref,
  -- offsets, sizes, strides, dest).
  let mut sizeOps : Std.HashSet ValuePtr := {}
  for op in ops do
    let name := opName ctx op
    -- D69: the dynamic sizes of a `memref.alloc` are its operands.
    if name == "memref.alloc" then
      for v in op.getOperands! ctx do sizeOps := sizeOps.insert v
      continue
    if name != "air.channel.put" && name != "air.channel.get" then continue
    let some seg := denseInts (findProp (unregProps ctx op) "operandSegmentSizes") | continue
    if seg.size < 5 then continue
    let start := (seg.extract 0 4).foldl (fun a n => a + n.toNat) 0
    let operands := op.getOperands! ctx
    for j in [start:start + seg[4]!.toNat] do
      if let some v := operands[j]? then sizeOps := sizeOps.insert v
  let mut out := []
  let mut pos := 0
  for v in block.getArguments! ctx, i in [0:block.getNumArguments! ctx] do
    let t := v.getType! ctx
    if Air.isAsyncToken t.val || isMemRefType t then continue
    let p := pos
    pos := pos + 1
    if (known[p]?.join).isSome || splits.any (·.pos == p) then continue
    let .ok carry := carriers ctx ops v | continue
    if carry.toList.any sizeOps.contains then out := out ++ [(p, i)]
  return out

/-- `known` with the split arguments set to `vs`. -/
def fill (known : List (Option Int)) (splits : List Split) (vs : List Int) : List (Option Int) :=
  let n := splits.foldl (fun m s => max m (s.pos + 1)) known.length
  (List.range n).map fun p =>
    match (splits.zip vs).find? (·.1.pos == p) with
    | some (_, v) => some v
    | none => known[p]?.join

end

end Veir.Air.ArgSplit
