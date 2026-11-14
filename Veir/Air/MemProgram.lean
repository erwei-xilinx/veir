module

public import Veir.Air.Extract
public import Veir.Air.Pattern
public import Veir.Air.Race

namespace Veir.Air

@[expose] public section

/-! # Layer 2: buffers, DMAs and what events read and write

`extractMem` reads a `func.func` whose body is a straight-line block of `air.execute`,
`air.wait_all`, `air.dma_memcpy_nd async` and host operations (`arith`, `memref.alloc`). It
returns the event graph (a `Program`, so the layer-1 graph results apply) and `MemInfo`, which
says:
- which buffer each memref value names;
- what each DMA moves.

From those, `footprints` computes what each event reads and writes (`Veir.Air.Race`), and
`finishMem` runs an event on a memory.

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
deriving Repr, Inhabited, BEq

def MemRefType.numel (t : MemRefType) : Nat := t.shape.foldl (· * ·) 1

/-- Row-major linear strides. -/
def MemRefType.strides (t : MemRefType) : List Int :=
  (t.shape.foldr (fun (d : Nat) (acc : List Int × Int) => (acc.2 :: acc.1, acc.2 * (d : Int))) ([], 1)).1

def leadingNat (cs : List Char) : Option (Nat × List Char) :=
  let ds := cs.takeWhile Char.isDigit
  if ds.isEmpty then none else some (String.ofList ds |>.toNat!, cs.drop ds.length)

/-- Read `memref<4x8xi32, 1>`: a static shape, an element type, an optional memory space. -/
def parseMemRefType (s : String) : Except String MemRefType := do
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
  let mut shape : List Nat := []
  repeat
    if rest.head? == some '?' then throw s!"'{s}': a dynamic shape is not supported"
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
  return { shape, elem, bitwidth, space }

/-! ### Values and memory -/

inductive Val where
  | rv (r : RuntimeValue)
  /-- Contents never written: what `memref.alloc` leaves (as upstream). -/
  | undef
  /-- A value the model does not compute (D22), as a function of what produced it. -/
  | opaque (op : Nat) (h : UInt64)
  /-- A memref value: the buffer it names. -/
  | buf (id : Nat)
deriving BEq, Inhabited

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

structure DmaInfo where
  dst : DmaSide
  src : DmaSide
  padBefore : Array Int
  padAfter : Array Int
deriving Inhabited

structure MemInfo where
  buffers : Array Buffer
  /-- The buffer each memref value names, where that is known when the program is read. -/
  bufOf : Std.HashMap ValuePtr Nat
  /-- Memref values that are views of their buffer (subviews, reshapes): only their buffer is
  known, not which elements. -/
  views : Std.HashSet ValuePtr
  /-- The DMA each DMA event performs. -/
  dmas : Std.HashMap Nat DmaInfo
  /-- Function arguments in order. -/
  args : Array (ValuePtr × String)
  /-- Host operations (`arith`, `memref.alloc`), in order. -/
  hostOps : Array OperationPtr
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
   "memref.reinterpret_cast", "memref.view", "memref.transpose"]

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
    return { memref := m,
             offsets := ← decodeList (← arr s!"static_{prefix_}_offsets") groups[offIdx]!,
             sizes := ← decodeList (← arr s!"static_{prefix_}_sizes") groups[offIdx + 1]!,
             strides := ← decodeList (← arr s!"static_{prefix_}_strides") groups[offIdx + 2]! }
  let dst ← side 1 2 "dst"
  let src ← side 5 6 "src"
  let padBefore := (denseInts (findProp props "pad_before")).getD #[]
  let padAfter := (denseInts (findProp props "pad_after")).getD #[]
  if padBefore.size != padAfter.size then throw "air.dma_memcpy_nd: pad_before and pad_after differ in rank"
  return { dst, src, padBefore, padAfter }

structure MemExtractState where
  eventOf : Std.HashMap OperationPtr Nat := {}
  hostOf : Std.HashSet OperationPtr := {}
  events : Array Event := #[]
  hostOps : Array OperationPtr := #[]
  blocking : List Nat := []
  buffers : Array Buffer := #[]
  bufOf : Std.HashMap ValuePtr Nat := {}
  views : Std.HashSet ValuePtr := {}
  dmas : Std.HashMap Nat DmaInfo := {}

def newBuffer (st : MemExtractState) (v : ValuePtr) (name : String) (t : TypeAttr) :
    Except String MemExtractState := do
  let ty ← parseMemRefType (typeString t)
  return { st with buffers := st.buffers.push { name, type := ty },
                   bufOf := st.bufOf.insert v st.buffers.size }

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

/-- Read a function as a layer-2 program. -/
def extractMem (ctx : IRContext OpCode) (func : OperationPtr) : Except String (Program × MemInfo) := do
  let .func .func := func.getOpType! ctx
    | throw s!"expected a func.func, but got '{opName ctx func}'"
  let block ← singleBlock ctx func "func.func"
  let ops := blockOps ctx block
  let mut st : MemExtractState := {}
  let mut args := #[]
  for v in block.getArguments! ctx, i in [0:block.getNumArguments! ctx] do
    let t := v.getType! ctx
    args := args.push (v, typeString t)
    if isMemRefType t then st ← newBuffer st v s!"%arg{i}" t
  for op in ops, idx in [0:ops.size] do
    let what := s!"operation #{idx} ('{opName ctx op}')"
    let name := opName ctx op
    let tokenOf := tokenEvent ctx { eventOf := st.eventOf } what
    match op.getOpType! ctx with
    | .air .execute | .air .wait_all =>
      let id := st.events.size
      let operandEvents ← (op.getOperands! ctx).mapM tokenOf
      let isExecute := op.getOpType! ctx == .air .execute
      let kind :=
        if isExecute then EventKind.execute
        else if op.getNumResults! ctx = 0 then EventKind.waitAllBlocking
        else EventKind.waitAll
      let mut body := #[]
      let mut yields := #[]
      let mut dataDeps : List Nat := []
      if isExecute then
        let b ← singleBlock ctx op what
        let bops := blockOps ctx b
        let some term := bops.back? | throw s!"{what}: expected a terminator"
        let .air .execute_terminator := term.getOpType! ctx
          | throw s!"{what}: expected the body to end in air.execute_terminator"
        body := bops.pop
        let mut inBody : Std.HashSet OperationPtr := {}
        for inner in body ++ #[term] do
          let iname := opName ctx inner
          let isOpaque := !(iname.startsWith "arith." || iname.startsWith "memref.") || iname == "memref.copy"
          if inner.getNumRegions! ctx ≠ 0 && !isOpaque then
            throw s!"{what}: '{iname}' has a region, which is not supported"
          -- Where every value it uses comes from (D4), and which buffers it names.
          for v in inner.getOperands! ctx do
            match v with
            | .blockArgument _ =>
              if !st.bufOf.contains v && !(args.any (·.1 == v)) then
                throw s!"{what}: '{iname}' reads a block argument, which is not supported"
            | .opResult ⟨d, i⟩ =>
              if inBody.contains d || st.hostOf.contains d then continue
              match st.eventOf[d]? with
              | some e =>
                if i = 0 then throw s!"{what}: '{iname}' uses a token as a value"
                if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
              | none => throw s!"{what}: '{iname}' reads a value of '{opName ctx d}', which is not supported"
          if iname == "memref.alloc" then
            st ← newBuffer st (.opResult ⟨inner, 0⟩) s!"alloc in event {id}" ((ValuePtr.opResult ⟨inner, 0⟩).getType! ctx)
          else if viewOps.contains iname then
            let some src := (inner.getOperands! ctx)[0]? | throw s!"{what}: '{iname}' without a source"
            if let some b := st.bufOf[src]? then
              st := { st with bufOf := st.bufOf.insert (.opResult ⟨inner, 0⟩) b,
                              views := st.views.insert (.opResult ⟨inner, 0⟩) }
          else if iname == "memref.load" || iname == "memref.store" then
            let m := (inner.getOperands! ctx)[if iname == "memref.load" then 0 else 1]!
            if st.views.contains m then
              throw s!"{what}: '{iname}' through a view is not supported"
          inBody := inBody.insert inner
        yields := term.getOperands! ctx
        let results := op.getResultTypes! ctx
        if yields.size + 1 ≠ results.size then
          throw s!"{what}: the terminator yields {yields.size} value(s), but the operation declares {results.size - 1}"
        for y in yields, i in [0:yields.size] do
          if (term.getOperandTypes! ctx)[i]! != results[i + 1]! then
            throw s!"{what}: the terminator yields {(term.getOperandTypes! ctx)[i]!} as value #{i}, but the operation declares {results[i + 1]!}"
          if let some b := st.bufOf[y]? then
            let r : ValuePtr := .opResult ⟨op, i + 1⟩
            st := { st with bufOf := st.bufOf.insert r b,
                            views := if st.views.contains y then st.views.insert r else st.views }
      st := { st with
        eventOf := st.eventOf.insert op id
        events := st.events.push
          { op, kind, operandEvents, implicitDeps := st.blocking, dataDeps, body, yields } }
      if kind = EventKind.waitAllBlocking then
        st := { st with blocking := st.blocking ++ [id] }
    | .builtin .unregistered =>
      if name == "air.dma_memcpy_nd" then
        -- Without `async` the DMA is synchronous: the host waits for it, so everything issued
        -- after it waits for it too (D24, as D1 for air.wait_all).
        let blocking := op.getNumResults! ctx = 0
        let id := st.events.size
        let info ← decodeDma ctx op
        let props := unregProps ctx op
        let nDeps := ((denseInts (findProp props "operandSegmentSizes")).getD #[0])[0]!.toNat
        let operandEvents ← ((op.getOperands! ctx).extract 0 nDeps).mapM tokenOf
        let mut dataDeps : List Nat := []
        for v in (op.getOperands! ctx).extract nDeps (op.getNumOperands! ctx) do
          if let .opResult ⟨d, i⟩ := v then
            if let some e := st.eventOf[d]? then
              if i = 0 then throw s!"{what}: a token used as a DMA operand"
              if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
        for m in [info.dst.memref, info.src.memref] do
          if st.views.contains m then
            throw s!"{what}: a DMA on a view is not supported; fold the view into the pattern first"
          if !st.bufOf.contains m then
            throw s!"{what}: the DMA's memref does not name a buffer the model knows"
        st := { st with
          eventOf := st.eventOf.insert op id
          dmas := st.dmas.insert id info
          events := st.events.push
            { op, kind := if blocking then .dmaBlocking else .dma, operandEvents,
              implicitDeps := st.blocking, dataDeps, body := #[], yields := #[] } }
        if blocking then
          st := { st with blocking := st.blocking ++ [id] }
      else if name == "memref.alloc" then
        st ← newBuffer st (.opResult ⟨op, 0⟩) s!"host alloc #{idx}" ((ValuePtr.opResult ⟨op, 0⟩).getType! ctx)
        st := { st with hostOf := st.hostOf.insert op, hostOps := st.hostOps.push op }
      else if name == "memref.dealloc" then
        throw s!"{what}: a host memref.dealloc is not an event and cannot be ordered; not supported"
      else
        if op.getNumRegions! ctx ≠ 0 then
          throw s!"{what}: '{name}' opens a nested region or scope, which is not supported"
        throw s!"{what}: '{name}' is not supported in a function body"
    | .arith _ =>
      st := { st with hostOf := st.hostOf.insert op, hostOps := st.hostOps.push op }
    | .func .return =>
      if idx + 1 ≠ ops.size then throw s!"{what}: expected func.return to be last"
    | _ =>
      if op.getNumRegions! ctx ≠ 0 then
        throw s!"{what}: '{name}' opens a nested region or scope, which is not supported"
      throw s!"{what}: '{name}' is not supported in a function body"
  let p : Program := { func, events := st.events, hostOps := st.hostOps }
  return (p, { buffers := st.buffers, bufOf := st.bufOf, views := st.views, dmas := st.dmas,
               args, hostOps := st.hostOps })

/-! ### Running -/

structure MState where
  values : Std.HashMap ValuePtr Val := {}
  mem : Std.HashMap (Nat × Int) Val := {}
  freed : Std.HashSet Nat := {}
  fault : Option String := none
deriving Inhabited

def MState.read (s : MState) (v : ValuePtr) : Option Val := s.values[v]?

def toRuntime? : Val → Option RuntimeValue
  | .rv r => some r
  | _ => none

/-- A deterministic stand-in for what an uninterpreted op computes from its inputs (D22). -/
def opaqueOf (op : OperationPtr) (inputs : List Val) (salt : Nat) : Val :=
  .opaque op.id (hash (", ".intercalate (inputs.map showVal) ++ s!"#{salt}"))

/-- The value written to a padded position (D20). -/
def zeroOf (t : MemRefType) : Val :=
  if t.bitwidth > 0 then .rv (.int t.bitwidth (.val 0)) else .opaque 0 0

/-- Initial memory: memref arguments hold `1000 · argument + element` (integers) or an opaque
value; scalar arguments are taken from `scalarArgs`, in order, or are 0 (`undef` when
`unknownScalars`). Host operations then run in order. -/
def MemInfo.initState (ctx : IRContext OpCode) (mi : MemInfo) (scalarArgs : List Int)
    (unknownScalars : Bool := false) : MState := Id.run do
  let mut s : MState := {}
  let mut scalars := scalarArgs
  for (v, ty) in mi.args, j in [0:mi.args.size] do
    if let some b := mi.bufOf[v]? then
      s := { s with values := s.values.insert v (.buf b) }
      let t := mi.buffers[b]!.type
      for p in [0:t.numel] do
        let x : Val := if t.bitwidth > 0 then .rv (.int t.bitwidth (.val (BitVec.ofInt t.bitwidth (1000 * j + p))))
          else .opaque 1000000 (1000 * j + p).toUInt64
        s := { s with mem := s.mem.insert (b, p) x }
    else
      let w := if ty == "index" then 64 else match ty.toList with
        | 'i' :: ds => (String.ofList ds).toNat?.getD 64
        | _ => 64
      let x : Val := match scalars with
        | n :: _ => .rv (.int w (.val (BitVec.ofInt w n)))
        | [] => if unknownScalars then .undef else .rv (.int w (.val 0))
      scalars := scalars.drop 1
      s := { s with values := s.values.insert v x }
  for op in mi.hostOps do
    if opName ctx op == "memref.alloc" then
      if let some b := mi.bufOf[ValuePtr.opResult ⟨op, 0⟩]? then
        s := { s with values := s.values.insert (.opResult ⟨op, 0⟩) (.buf b) }
      continue
    let ins := (op.getOperands! ctx).toList.map fun v => s.values[v]?.getD .undef
    match ins.mapM toRuntime? with
    | some rs =>
      match evalArith ctx op rs.toArray with
      | .ok results =>
        for r in results, i in [0:results.size] do
          s := { s with values := s.values.insert (.opResult ⟨op, i⟩) (.rv r) }
      | .error msg => return { s with fault := some msg }
    | none =>
      for i in [0:op.getNumResults! ctx] do
        s := { s with values := s.values.insert (.opResult ⟨op, i⟩) .undef }
  return s

/-- A pattern's entries, given operand values. `none` if one is not a known integer. -/
def evalEntries (s : MState) (xs : Array (Int ⊕ ValuePtr)) : Option (Array Int) :=
  xs.mapM fun
    | .inl n => some n
    | .inr v => s.values[v]? >>= Val.toInt?

/-- The positions one side of a DMA touches, from known entries (D14); the whole buffer when
the pattern is empty. -/
def sidePositions (t : MemRefType) (offs sizes strides : Array Int) : Except String (List Dim) := do
  if offs.isEmpty && sizes.isEmpty && strides.isEmpty then
    return [⟨0, t.numel, 1⟩]
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
    if p < 0 || p ≥ t.numel then
      throw s!"position {p} is outside {name} ({t.numel} elements)"

/-- What finishing a DMA does (D20, D21). -/
def finishDma (mi : MemInfo) (info : DmaInfo) (v : Nat) (s : MState) : MState := Id.run do
  let fail (m : String) : MState := { s with fault := some s!"event {v} (air.dma_memcpy_nd): {m}" }
  let some (.buf sb) := s.read info.src.memref | return fail "its source buffer is not available"
  let some (.buf db) := s.read info.dst.memref | return fail "its destination buffer is not available"
  if s.freed.contains sb || s.freed.contains db then return fail "a buffer it uses was deallocated"
  let st := mi.buffers[sb]!.type
  let dt := mi.buffers[db]!.type
  let some so := evalEntries s info.src.offsets | return fail "a source offset is not known"
  let some sz := evalEntries s info.src.sizes | return fail "a source size is not known"
  let some ss := evalEntries s info.src.strides | return fail "a source stride is not known"
  let some dO := evalEntries s info.dst.offsets | return fail "a destination offset is not known"
  let some dz := evalEntries s info.dst.sizes | return fail "a destination size is not known"
  let some ds := evalEntries s info.dst.strides | return fail "a destination stride is not known"
  match (do
      let sdims ← sidePositions st so sz ss
      let ddims ← sidePositions dt dO dz ds
      let stream ← srcStream sdims info.padBefore info.padAfter
      let dpos := positions ddims
      if stream.length != dpos.length then
        throw s!"the source stream has {stream.length} element(s) but the destination pattern {dpos.length} (D20)"
      checkBounds st mi.buffers[sb]!.name (stream.filterMap id)
      checkBounds dt mi.buffers[db]!.name dpos
      pure (stream, dpos) : Except String _) with
  | .error m => return fail m
  | .ok (stream, dpos) =>
    -- Read the whole stream, then write it in order: the result of every well-defined overlap
    -- (D21), and the last write wins.
    let vals := stream.map fun
      | some p => s.mem[(sb, p)]?.getD .undef
      | none => zeroOf st
    let mut mem := s.mem
    for p in dpos, x in vals do
      mem := mem.insert (db, p) x
    return { s with mem }

/-- What finishing an `air.execute` does: run its body in order, then publish what it yields. -/
def finishExecute (ctx : IRContext OpCode) (mi : MemInfo) (e : Event) (v : Nat) (s : MState) : MState := Id.run do
  let fail (m : String) : MState := { s with fault := some s!"event {v}: {m}" }
  let mut vals := s.values
  let mut mem := s.mem
  let mut freed := s.freed
  for inner in e.body do
    let iname := opName ctx inner
    let operands := inner.getOperands! ctx
    let mut ins := #[]
    for o in operands do
      match vals[o]? with
      | some x => ins := ins.push x
      | none =>
        match o with
        | .opResult ⟨d, _⟩ => return fail s!"'{iname}' read a result of '{opName ctx d}' before it was available"
        | .blockArgument _ => return fail s!"'{iname}' read an unknown block argument"
    let bufOfVal (x : Val) : Option Nat := match x with | .buf b => some b | _ => none
    let position (b : Nat) (idx : Array Val) : Except String Int := do
      let t := mi.buffers[b]!.type
      if idx.size != t.shape.length then throw "wrong number of indices"
      let mut p : Int := 0
      for i in idx, d in t.shape, stv in t.strides do
        let some n := i.toInt? | throw "an index is not a known integer"
        if n < 0 || n ≥ d then throw s!"index {n} is outside a dimension of size {d}"
        p := p + n * stv
      return p
    if iname == "memref.alloc" then
      if let some b := mi.bufOf[ValuePtr.opResult ⟨inner, 0⟩]? then
        vals := vals.insert (.opResult ⟨inner, 0⟩) (.buf b)
        freed := freed.erase b
    else if viewOps.contains iname then
      if let some x := ins[0]? then vals := vals.insert (.opResult ⟨inner, 0⟩) x
    else if iname == "memref.dealloc" then
      let some b := ins[0]? >>= bufOfVal | return fail "memref.dealloc of an unknown buffer"
      if freed.contains b then return fail s!"{mi.buffers[b]!.name} deallocated twice"
      freed := freed.insert b
    else if iname == "memref.load" then
      let some b := ins[0]? >>= bufOfVal | return fail "memref.load of an unknown buffer"
      if freed.contains b then return fail s!"memref.load after {mi.buffers[b]!.name} was deallocated"
      match position b (ins.extract 1 ins.size) with
      | .error m => return fail s!"memref.load: {m}"
      | .ok p => vals := vals.insert (.opResult ⟨inner, 0⟩) (mem[(b, p)]?.getD .undef)
    else if iname == "memref.store" then
      let some b := ins[1]? >>= bufOfVal | return fail "memref.store to an unknown buffer"
      if freed.contains b then return fail s!"memref.store after {mi.buffers[b]!.name} was deallocated"
      match position b (ins.extract 2 ins.size) with
      | .error m => return fail s!"memref.store: {m}"
      | .ok p => mem := mem.insert (b, p) ins[0]!
    else if iname.startsWith "arith." then
      match ins.toList.mapM toRuntime? with
      | some rs =>
        match evalArith ctx inner rs.toArray with
        | .ok results =>
          for r in results, i in [0:results.size] do
            vals := vals.insert (.opResult ⟨inner, i⟩) (.rv r)
        | .error m => return fail m
      | none =>
        let r : Val := if ins.any (· == .undef) then .undef else opaqueOf inner ins.toList 0
        for i in [0:inner.getNumResults! ctx] do vals := vals.insert (.opResult ⟨inner, i⟩) r
    else
      -- Not interpreted (D22): read everything it touches, write opaque values to what it
      -- writes, and give its results opaque values.
      let bufs := (memrefOperands ctx inner).filterMap fun m => vals[m]? >>= bufOfVal
      for b in bufs do
        if freed.contains b then return fail s!"'{iname}' used {mi.buffers[b]!.name} after it was deallocated"
      let readVals := ins.toList ++ bufs.toList.flatMap fun b =>
        (List.range mi.buffers[b]!.type.numel).map fun (p : Nat) => mem[(b, (p : Int))]?.getD .undef
      let written := writtenBuffers ctx inner (fun m => vals[m]? >>= bufOfVal)
      for b in written do
        for p in [0:mi.buffers[b]!.type.numel] do
          mem := mem.insert (b, p) (opaqueOf inner readVals p)
      for i in [0:inner.getNumResults! ctx] do
        if !isMemRefType ((ValuePtr.opResult ⟨inner, i⟩).getType! ctx) then
          vals := vals.insert (.opResult ⟨inner, i⟩) (opaqueOf inner readVals (1000000 + i))
  let mut out := s.values
  for y in e.yields, i in [0:e.yields.size] do
    match vals[y]? with
    | some x => out := out.insert (.opResult ⟨e.op, i + 1⟩) x
    | none => return fail "it yields a value that was not available"
  return { s with values := out, mem, freed }
where
  /-- The buffers an uninterpreted op writes: a linalg op's `outs`, `memref.copy`'s target, and
  otherwise every memref it touches (D22). -/
  writtenBuffers (ctx : IRContext OpCode) (inner : OperationPtr) (bufOf : ValuePtr → Option Nat) :
      Array Nat :=
    let name := opName ctx inner
    let operands := inner.getOperands! ctx
    if name == "memref.copy" then
      (operands.extract 1 2).filterMap bufOf
    else if name.startsWith "linalg." then
      match denseInts (findProp (unregProps ctx inner) "operandSegmentSizes") with
      | some #[nIns, nOuts] => (operands.extract nIns.toNat (nIns.toNat + nOuts.toNat)).filterMap bufOf
      | _ => (memrefOperands ctx inner).filterMap bufOf
    else (memrefOperands ctx inner).filterMap bufOf

def finishMem (ctx : IRContext OpCode) (p : Program) (mi : MemInfo) (v : Nat) (s : MState) : MState :=
  if s.fault.isSome then s else
  match p.events[v]? with
  | none => { s with fault := some s!"event {v} does not exist" }
  | some e =>
    match e.kind with
    | .execute => finishExecute ctx mi e v s
    | .dma | .dmaBlocking =>
      match mi.dmas[v]? with
      | some info => finishDma mi info v s
      | none => { s with fault := some s!"event {v}: no DMA information" }
    | _ => s

def runMem (ctx : IRContext OpCode) (p : Program) (mi : MemInfo) (init : MState) (order : List Nat) : MState :=
  order.foldl (fun s v => finishMem ctx p mi v s) init

/-! ### Footprints -/

/-- One problem inside a single event: an invalid DMA, or a race within a DMA (D21). -/
structure EventIssue where
  event : Nat
  msg : String

/-- What each event reads and writes, computed from what is known before running: constants,
host arithmetic, and the scalar arguments in `init` (unknown ones are `undef`). An access whose
elements are not known is the whole buffer (D23). Also returns the problems found inside single
events. -/
def footprints (ctx : IRContext OpCode) (p : Program) (mi : MemInfo) (init : MState) :
    Array (List Access) × Array EventIssue := Id.run do
  let whole (b : Nat) : List Int := (List.range mi.buffers[b]!.type.numel).map Int.ofNat
  let staticBuf (v : ValuePtr) : Option Nat := mi.bufOf[v]?
  let mut fps := #[]
  let mut issues := #[]
  for e in p.events, v in [0:p.events.size] do
    let mut acc : List Access := []
    match e.kind with
    | .dma | .dmaBlocking =>
      let info := mi.dmas[v]!
      let some sb := staticBuf info.src.memref | fps := fps.push acc; continue
      let some db := staticBuf info.dst.memref | fps := fps.push acc; continue
      let st := mi.buffers[sb]!.type
      let dt := mi.buffers[db]!.type
      let known := do
        let so ← evalEntries init info.src.offsets
        let sz ← evalEntries init info.src.sizes
        let ss ← evalEntries init info.src.strides
        let dO ← evalEntries init info.dst.offsets
        let dz ← evalEntries init info.dst.sizes
        let ds ← evalEntries init info.dst.strides
        pure (so, sz, ss, dO, dz, ds)
      match known with
      | none =>
        acc := [⟨sb, .read, whole sb⟩, ⟨db, .write, whole db⟩]
      | some (so, sz, ss, dO, dz, ds) =>
        match (do
            let sdims ← sidePositions st so sz ss
            let ddims ← sidePositions dt dO dz ds
            let stream ← srcStream sdims info.padBefore info.padAfter
            pure (stream, positions ddims) : Except String _) with
        | .error m =>
          issues := issues.push ⟨v, s!"invalid air.dma_memcpy_nd: {m}"⟩
          acc := [⟨sb, .read, whole sb⟩, ⟨db, .write, whole db⟩]
        | .ok (stream, dpos) =>
          if stream.length != dpos.length then
            issues := issues.push ⟨v, s!"invalid air.dma_memcpy_nd: the source stream has {stream.length} element(s) but the destination pattern {dpos.length} (D20)"⟩
          let reads := stream.filterMap id
          acc := [⟨sb, .read, reads⟩, ⟨db, .write, dpos⟩]
          if let .error m := checkBounds st mi.buffers[sb]!.name reads then
            issues := issues.push ⟨v, s!"air.dma_memcpy_nd reads out of bounds: {m}"⟩
          if let .error m := checkBounds dt mi.buffers[db]!.name dpos then
            issues := issues.push ⟨v, s!"air.dma_memcpy_nd writes out of bounds: {m}"⟩
          -- D21: within the DMA, a location read at step i and written at step j needs i ≤ j.
          if sb == db then
            let mut firstWrite : Std.HashMap Int Nat := {}
            for x in dpos, j in [0:dpos.length] do
              if !firstWrite.contains x then firstWrite := firstWrite.insert x j
            for x? in stream, i in [0:stream.length] do
              if let some x := x? then
                if let some j := firstWrite[x]? then
                  if i > j then
                    issues := issues.push ⟨v, s!"race inside air.dma_memcpy_nd on {mi.buffers[sb]!.name}: element {x} is read at step {i}, after it may already be written at step {j} (D21)"⟩
                    break
    | .execute =>
      -- A static pass over the body: constant indices are evaluated, anything else is unknown.
      let mut vals := init.values
      for inner in e.body do
        let iname := opName ctx inner
        let operands := inner.getOperands! ctx
        let bufOf (o : ValuePtr) : Option Nat := staticBuf o
        let index (b : Nat) (idx : Array ValuePtr) : Option Int := do
          let t := mi.buffers[b]!.type
          if idx.size != t.shape.length then none
          let mut q : Int := 0
          for i in idx, stv in t.strides do
            let n ← vals[i]? >>= Val.toInt?
            q := q + n * stv
          return q
        if iname.startsWith "arith." then
          let ins := operands.toList.map fun o => vals[o]?.getD .undef
          if let some rs := ins.mapM toRuntime? then
            if let .ok results := evalArith ctx inner rs.toArray then
              for r in results, i in [0:results.size] do
                vals := vals.insert (.opResult ⟨inner, i⟩) (.rv r)
        else if iname == "memref.alloc" || viewOps.contains iname then
          pure ()
        else if iname == "memref.dealloc" then
          if let some b := operands[0]? >>= bufOf then acc := acc ++ [⟨b, .write, whole b⟩]
        else if iname == "memref.load" then
          if let some b := operands[0]? >>= bufOf then
            acc := acc ++ [⟨b, .read, match index b (operands.extract 1 operands.size) with
              | some q => [q] | none => whole b⟩]
        else if iname == "memref.store" then
          if let some b := operands[1]? >>= bufOf then
            acc := acc ++ [⟨b, .write, match index b (operands.extract 2 operands.size) with
              | some q => [q] | none => whole b⟩]
        else
          let touched := (memrefOperands ctx inner).filterMap bufOf
          let written := finishExecute.writtenBuffers ctx inner bufOf
          for b in touched do
            acc := acc ++ [⟨b, .read, whole b⟩]
          for b in written do
            acc := acc ++ [⟨b, .write, whole b⟩]
    | _ => pure ()
    fps := fps.push acc
  return (fps, issues)

/-- A pair of events that conflict without being ordered, with one witness. -/
structure RaceReport where
  first : Nat
  second : Nat
  kind : String
  buffer : String
  element : Int

/-- The races of a program: exactly `races` (`Veir.Air.Race`, proven exact by `raceFreeB_iff`),
with a witness for each. -/
def raceReports (p : Program) (mi : MemInfo) (fps : Array (List Access)) : List RaceReport :=
  let fp : Footprint := fun v => fps[v]?.getD []
  (races p.graph fp).filterMap fun (u, v) => do
    -- A witness: the first conflicting pair of accesses and a common element.
    for a in fp u do
      for b in fp v do
        if a.conflictsB b then
          let bs : Std.HashSet Int := Std.HashSet.ofList b.elems
          if let some x := a.elems.find? bs.contains then
            let kind := match a.kind, b.kind with
              | .write, .read => "RAW" | .read, .write => "WAR" | _, _ => "WAW"
            return { first := u, second := v, kind, buffer := mi.buffers[a.buf]!.name, element := x }
    none

end

end Veir.Air
