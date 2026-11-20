module

public import Veir.Air.Extract
public import Veir.Air.Pattern
public import Veir.Air.Race

namespace Veir.Air

@[expose] public section

/-! # Layer 2: buffers, DMAs and what events read and write

The types and pieces layer 2 is built from: memref types, values, buffers, DMA patterns and their
streams. `Veir.Air.Instance` uses them to instantiate a function's events, compute what each
reads and writes (`Veir.Air.Race`), and run them on a memory.

The meaning follows `SEMANTICS.md`:
- **D14:** access patterns;
- **D19:** top-level memref arguments are distinct buffers;
- **D20:** a DMA is a stream, with zero padding on the source side;
- **D21:** within one DMA, a location read at step `i` and written at step `j` is well defined
  iff `i ≤ j`, and the last of several writes wins;
- **D22:** an op the model does not interpret reads and writes every memref it touches (linalg:
  `ins` read, `outs` read and written), and its values are opaque;
- **D23:** a non-constant pattern is evaluated when running and is the whole buffer statically;
- **D17:** `memref.dealloc` writes the whole buffer.

A DMA without `async` is synchronous (D24): the host waits for it, so it orders everything after
it, as a blocking `air.wait_all` does.

**Refused, each with a diagnostic:**
- a DMA on a view (a subview or reshape result), which the canonicalizer folds away;
- `memref.load`/`store` through a view;
- a memref type with a non-identity layout or a dynamic shape;
- a host `memref.dealloc`, which is not an event and so cannot be ordered.
-/

/-! ### Memref types -/

structure MemRefType where
  shape : List Nat
  elem : String
  /-- The element's width when it is an integer (`index` is 64), else 0. -/
  bitwidth : Nat
  space : Nat
  /-- `memref<*xT>`: a bare pointer (D63). No upper bound; its extent is how far its accesses
  reach (`IProgram.sizeBarePointers` sets `shape` to it). -/
  unranked : Bool := false
  /-- D70: a leading dynamic dimension with no cast to fix it: as a bare pointer (D63) in that
  dimension, its length how far its accesses reach (`IProgram.sizeBarePointers`). -/
  leadingDyn : Bool := false
deriving Repr, Inhabited, BEq

def MemRefType.numel (t : MemRefType) : Nat := t.shape.foldl (· * ·) 1

/-- Whether position `p` lies in a buffer of type `t`: a bare pointer (D63) only needs `p ≥ 0`. -/
def MemRefType.inBounds (t : MemRefType) (p : Int) : Bool :=
  p ≥ 0 && (t.unranked || t.leadingDyn || p < t.numel)

/-- Row-major linear strides. -/
def MemRefType.strides (t : MemRefType) : List Int :=
  (t.shape.foldr (fun (d : Nat) (acc : List Int × Int) => (acc.2 :: acc.1, acc.2 * (d : Int))) ([], 1)).1

def leadingNat (cs : List Char) : Option (Nat × List Char) :=
  let ds := cs.takeWhile Char.isDigit
  if ds.isEmpty then none else some (String.ofList ds |>.toNat!, cs.drop ds.length)

/-- Read `memref<4x8xi32, 1>`: a static shape, an element type, an optional memory space. A
dynamic dimension `?` takes the next of `dims` (D68, D69); with none left, a leading one is a bare
pointer's when `leadingBare` (D70), and anything else is refused. -/
def parseMemRefType (s : String) (dims : List Nat := []) (leadingBare : Bool := false) :
    Except String MemRefType := do
  let cs := s.toList
  let pre := "memref<".toList
  unless cs.take pre.length == pre && cs.getLast? == some '>' do
    throw s!"'{s}' is not a memref type"
  let inner := (cs.drop pre.length).dropLast
  if inner.contains '<' then
    throw s!"'{s}': a memref with a non-identity layout is not supported"
  let parts := (String.ofList inner).splitOn ","
  let some shapePart := parts[0]? | throw s!"'{s}': no shape"
  -- Dimensions are `Nx` prefixes; what remains is the element type (which may contain an `x`).
  let mut rest := shapePart.trimAscii.toString.toList
  -- `*x`: unranked, a bare pointer (D63).
  let unranked := rest.take 2 == ['*', 'x']
  if unranked then rest := rest.drop 2
  let mut shape : List Nat := []
  let mut dims := dims
  let mut leadingDyn := false
  repeat
    if rest.take 2 == ['?', 'x'] then
      match dims with
      | d :: ds => shape := shape ++ [d]; dims := ds; rest := rest.drop 2; continue
      | [] =>
        if leadingBare && shape.isEmpty && !unranked then
          leadingDyn := true; shape := [0]; rest := rest.drop 2; continue
        throw s!"'{s}': a dynamic shape is not supported"
    match leadingNat rest with
    | some (n, 'x' :: tl) => shape := shape ++ [n]; rest := tl
    | _ => break
  let elem := String.ofList rest
  let bitwidth :=
    if elem == "index" then 64
    else match elem.toList with
      | 'i' :: ds => (String.ofList ds).toNat?.getD 0
      | _ => 0
  let space ← match parts[1]? with
    | none => pure 0
    | some sp =>
      match leadingNat sp.trimAscii.toString.toList with
      | some (n, _) => pure n
      | none => throw s!"'{s}': unsupported memory space"
  return { shape, elem, bitwidth, space, unranked, leadingDyn }

/-- The shape of a memref type, whatever its layout (`strided<...>` included): the type up to its
first comma read as an identity-layout memref. -/
def memrefShape? (s : String) : Option (List Nat) :=
  let head := (s.splitOn ",").headD s
  let ty := if head == s then s else head ++ ">"
  (parseMemRefType ty).toOption.map (·.shape)

/-! ### Values and memory -/

inductive Val where
  | rv (r : RuntimeValue)
  /-- Contents never written: what `memref.alloc` leaves (as upstream). -/
  | undef
  /-- A value the model does not compute (D22), as a function of what produced it. -/
  | opaque (op : Nat) (h : UInt64)
  /-- A memref value: the buffer it names. -/
  | buf (id : Nat)
deriving DecidableEq, Inhabited

def Val.toInt? : Val → Option Int
  | .rv (.int _ (.val b)) => some b.toInt
  | _ => none

def showVal : Val → String
  | .rv (.int _ (.val b)) => toString b.toInt
  | .rv (.int _ .poison) => "poison"
  | .rv r => toString r
  | .undef => "undef"
  | .opaque op h => s!"opaque<{op}:{h % 10000}>"
  | .buf id => s!"buffer {id}"

structure Buffer where
  name : String
  type : MemRefType
deriving Inhabited

/-- One side of a DMA: a memref and its pattern. Each entry of the pattern is a constant or the
value of an operand. -/
structure DmaSide where
  memref : ValuePtr
  offsets : Array (Int ⊕ ValuePtr)
  sizes : Array (Int ⊕ ValuePtr)
  strides : Array (Int ⊕ ValuePtr)
deriving Inhabited

/-- D65: offsets, sizes and strides of different lengths are padded in front to the longest, as
AIR's `canonicalizeAIRDmaOperands` does: offsets with 0, sizes with 1, strides with the memref's
element count (`numel`; with size 1 and offset 0 a padded stride moves nothing). -/
def DmaSide.padFront (s : DmaSide) (numel : Int) : DmaSide :=
  let n := max s.offsets.size (max s.sizes.size s.strides.size)
  let pad (xs : Array (Int ⊕ ValuePtr)) (v : Int) : Array (Int ⊕ ValuePtr) :=
    Array.replicate (n - xs.size) (.inl v) ++ xs
  -- An empty pattern is the whole buffer; offsets alone omitted are D14a's zeros, the same.
  if n == 0 then s
  else { s with offsets := pad s.offsets 0, sizes := pad s.sizes 1, strides := pad s.strides numel }

structure DmaInfo where
  dst : DmaSide
  src : DmaSide
  padBefore : Array Int
  padAfter : Array Int
deriving Inhabited

/-! ### Reading the program -/

/-- An unregistered operation's properties. -/
def unregProps (ctx : IRContext OpCode) (op : OperationPtr) : Array (ByteArray × Attribute) :=
  match op.getOpType! ctx with
  | .builtin .unregistered =>
    (op.getProperties! ctx (OpCode.builtin Builtin.unregistered)).properties.entries
  | _ => #[]

def findProp (props : Array (ByteArray × Attribute)) (name : String) : Option Attribute :=
  (props.find? (·.1 == name.toUTF8)).map (·.2)

def denseInts : Option Attribute → Option (Array Int)
  | some (.denseArrayAttr d) => some d.values
  | _ => none

def typeString (t : TypeAttr) : String := Attribute.toString t.val

def isMemRefType (t : TypeAttr) : Bool := (typeString t).startsWith "memref<"

/-- The ops that only re-describe a buffer. -/
def viewOps : List String :=
  ["memref.subview", "memref.expand_shape", "memref.collapse_shape", "memref.cast",
   "memref.reinterpret_cast", "memref.view", "memref.transpose", "memref.reshape"]

/-- `INT64_MIN`, MLIR's marker for a dynamic entry of a static array. -/
def dynamicMarker : Int := -9223372036854775808

def decodeList (stat : Array Int) (dyn : Array ValuePtr) : Except String (Array (Int ⊕ ValuePtr)) := do
  let mut out := #[]
  let mut next := 0
  for v in stat do
    if v == dynamicMarker then
      let some d := dyn[next]? | throw "air.dma_memcpy_nd: fewer dynamic operands than markers"
      out := out.push (.inr d); next := next + 1
    else out := out.push (.inl v)
  return out

/-- The element count of a memref value's type, for `DmaSide.padFront` (0 when not known). -/
def numelOf (ctx : IRContext OpCode) (v : ValuePtr) : Int :=
  match parseMemRefType (typeString (v.getType! ctx)) with
  | .ok t => if t.unranked then 0 else t.numel
  | .error _ => 0

/-- Read an `air.dma_memcpy_nd`'s operands and pattern properties. -/
def decodeDma (ctx : IRContext OpCode) (op : OperationPtr) : Except String DmaInfo := do
  let props := unregProps ctx op
  let some seg := denseInts (findProp props "operandSegmentSizes")
    | throw "air.dma_memcpy_nd: missing operandSegmentSizes"
  if seg.size != 9 then throw "air.dma_memcpy_nd: expected 9 operand segments"
  let operands := op.getOperands! ctx
  let mut groups : Array (Array ValuePtr) := #[]
  let mut start := 0
  for n in seg do
    groups := groups.push (operands.extract start (start + n.toNat))
    start := start + n.toNat
  let arr (name : String) : Except String (Array Int) :=
    match denseInts (findProp props name) with
    | some a => pure a
    | none => throw s!"air.dma_memcpy_nd: missing {name}"
  let side (memrefGroup offIdx : Nat) (prefix_ : String) : Except String DmaSide := do
    let some m := groups[memrefGroup]!.toList.head? | throw s!"air.dma_memcpy_nd: no {prefix_} memref"
    let offsets ← decodeList (← arr s!"static_{prefix_}_offsets") groups[offIdx]!
    let sizes ← decodeList (← arr s!"static_{prefix_}_sizes") groups[offIdx + 1]!
    let strides ← decodeList (← arr s!"static_{prefix_}_strides") groups[offIdx + 2]!
    return ({ memref := m, offsets, sizes, strides } : DmaSide).padFront (numelOf ctx m)
  let dst ← side 1 2 "dst"
  let src ← side 5 6 "src"
  let padBefore := (denseInts (findProp props "pad_before")).getD #[]
  let padAfter := (denseInts (findProp props "pad_after")).getD #[]
  if padBefore.size != padAfter.size then throw "air.dma_memcpy_nd: pad_before and pad_after differ in rank"
  return { dst, src, padBefore, padAfter }

/-- The memref values an op touches: its memref operands and, inside its regions, those defined
outside it. -/
partial def memrefOperands (ctx : IRContext OpCode) (op : OperationPtr) : Array ValuePtr := Id.run do
  let mut out := (op.getOperands! ctx).filter fun v => isMemRefType (v.getType! ctx)
  for r in [0:op.getNumRegions! ctx] do
    let some b := (op.getRegion! ctx r).getFirstBlock! ctx | continue
    for inner in blockOps ctx b do
      for v in memrefOperands ctx inner do
        if !out.contains v then out := out.push v
  return out

/-! ### Running -/

def toRuntime? : Val → Option RuntimeValue
  | .rv r => some r
  | _ => none

/-- A deterministic stand-in for what an uninterpreted op computes from its inputs (D22). -/
def opaqueOf (op : OperationPtr) (inputs : List Val) (salt : Nat) : Val :=
  .opaque op.id (hash (", ".intercalate (inputs.map showVal) ++ s!"#{salt}"))

/-- The inputs of an uninterpreted op, hashed once (`opaqueOfH`). -/
def hashInputs (inputs : List Val) : UInt64 := inputs.foldl (fun h v => mixHash h (hash (showVal v))) 7

/-- `opaqueOf` from hashed inputs: for an op writing many positions from the same inputs, which
would otherwise hash all of them once per position. -/
def opaqueOfH (op : OperationPtr) (h : UInt64) (salt : Nat) : Val := .opaque op.id (mixHash h (hash salt))

/-- The value written to a padded position (D20). -/
def zeroOf (t : MemRefType) : Val :=
  if t.bitwidth > 0 then .rv (.int t.bitwidth (.val 0)) else .opaque 0 0

/-- The positions one side of a DMA touches, from known entries (D14); the whole buffer when
the pattern is empty. -/
def sidePositions (t : MemRefType) (offs sizes strides : Array Int) : Except String (List Dim) := do
  if offs.isEmpty && sizes.isEmpty && strides.isEmpty then
    if t.unranked then throw "a bare pointer (unranked memref, D63) as a whole transfer end has no length"
    if t.leadingDyn then
      throw "a memref with a leading dynamic dimension (D70) as a whole transfer end has no length"
    return [⟨0, t.numel, 1⟩]
  -- No offsets with sizes and strides: every offset 0 (D14a, as AIR's `get1DOffset` reads it).
  let offs := if offs.isEmpty then Array.replicate sizes.size 0 else offs
  if offs.size != sizes.size || sizes.size != strides.size then
    throw "offsets, sizes and strides differ in length"
  let mut ds := []
  for o in offs, n in sizes, st in strides do
    if n < 0 then throw "negative size"
    ds := ds ++ [⟨o, n.toNat, st⟩]
  return ds

/-- The padded source stream (D20): `none` is a padded zero. -/
def streamFrom (base : Int) : List (Dim × Nat × Nat) → List (Option Int)
  | [] => [some base]
  | (d, b, a) :: ds =>
    let blockLen := (ds.map fun (d', b', a') => d'.size + b' + a').foldl (· * ·) 1
    List.replicate (b * blockLen) none ++
      ((List.range d.size).flatMap fun (k : Nat) => streamFrom (base + (d.offset + k) * d.stride) ds) ++
      List.replicate (a * blockLen) none

def srcStream (dims : List Dim) (pb pa : Array Int) : Except String (List (Option Int)) := do
  if pb.isEmpty then return (positions dims).map some
  if pb.size != dims.length then throw "padding rank differs from the source pattern's"
  return streamFrom 0 (dims.zip ((pb.toList.map Int.toNat).zip (pa.toList.map Int.toNat)))

def checkBounds (t : MemRefType) (name : String) (ps : List Int) : Except String Unit := do
  for p in ps do
    if !t.inBounds p then
      throw (if t.unranked then s!"position {p} is before the start of {name} (a bare pointer, D63)"
        else s!"position {p} is outside {name} ({t.numel} elements)")

/-! ### Footprints -/

/-- One problem inside a single event: an invalid DMA, or a race within a DMA (D21). -/
structure EventIssue where
  event : Nat
  msg : String

/-- A pair of events that conflict without being ordered, with one witness. -/
structure RaceReport where
  first : Nat
  second : Nat
  kind : String
  buffer : String
  element : Int


end

end Veir.Air
