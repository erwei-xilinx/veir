module

public import Veir.Air.MemProgram
public import Veir.Air.Affine

namespace Veir.Air

@[expose] public section

/-! # Layers 2 and 3: instantiating a function's events

`instantiate` walks a function the way the host executes it: in program order, computing host
arithmetic, and running `scf.for` and `scf.parallel` loops iteration by iteration. Every
`air.execute`, `air.wait_all` and `air.dma_memcpy_nd` it meets becomes an event *instance*. Each
instance remembers:
- the values it captured: loop induction variables, loop-carried tokens, results of other
  instances;
- the buffers its own `memref.alloc`s create (a new one every time).

The events form an ordinary `Program`, so every layer-1 result about graphs applies to it.

Loop semantics (`SEMANTICS.md` D26, D27, from `docs/AIRComputeModel.md`):
- **`scf.for`:** iterations are issued in order, and iteration N+1 is ordered after iteration N
  only through the tokens its `iter_args` carry ("an op that does not depend on `%t_prev` may
  begin before iteration N's `scf.yield` fires").
- **`scf.parallel`:** all iterations are concurrent, and its result is its reduction of the
  iterations' values. The reduction region is instantiated as a left fold in iteration order,
  which is exact for the `air.wait_all` reductions AIR uses.

Loop bounds must be known: they are computed from constants and the scalar arguments given.
-/

/-- What the host knows a value to be while it walks the program. -/
inductive HVal where
  /-- The token of an event instance. -/
  | tok (event : Nat)
  /-- A value the host computed (`undef` when it depends on an argument not given). -/
  | val (v : Val)
  /-- Result `idx` (≥ 1) of an `air.execute` instance: available once that instance finished. -/
  | result (event : Nat) (idx : Nat)
deriving Inhabited, BEq

structure EventCtx where
  /-- The values from outside it that the instance uses. -/
  env : Std.HashMap ValuePtr HVal := {}
  /-- The buffer each `memref.alloc` in its body creates. -/
  allocBufs : Std.HashMap OperationPtr Nat := {}
  /-- The loop iterations and hierarchy instances it belongs to, outermost first. -/
  path : List Int := []
  /-- The `air.launch` instance it belongs to: the launch's start event, and the instance. -/
  launchInst : Option (Nat × List Int) := none
deriving Inhabited

/-- An `air.channel` declaration. -/
structure ChanDecl where
  name : String
  size : List Nat
  broadcast : Option (List Nat)
  type : String
deriving Inhabited

/-- One channel endpoint: which subchannel, what it moves, and (for a put) the destination a
packet flow selects. -/
structure ChanInfo where
  chan : String
  isPut : Bool
  indices : List Int
  side : DmaSide
  padBefore : Array Int
  padAfter : Array Int
  dest : Option Int
deriving Inhabited

structure IProgram where
  prog : Program
  ctxs : Array EventCtx
  buffers : Array Buffer
  dmas : Std.HashMap Nat DmaInfo
  /-- The buffer an `air.execute` instance's memref result names. -/
  resultBufs : Std.HashMap (Nat × Nat) Nat
  /-- Memref results that are views (subviews, reshapes) of their buffer. -/
  viewResults : Std.HashSet (Nat × Nat)
  /-- The buffers of the memref arguments, with their names, in order. -/
  argBufs : Array Nat
  /-- How many loops were instantiated. -/
  loops : Nat
  chanDecls : Std.HashMap String ChanDecl := {}
  chans : Std.HashMap Nat ChanInfo := {}
deriving Inhabited

structure IState where
  events : Array Event := #[]
  ctxs : Array EventCtx := #[]
  blocking : List Nat := []
  buffers : Array Buffer := #[]
  dmas : Std.HashMap Nat DmaInfo := {}
  resultBufs : Std.HashMap (Nat × Nat) Nat := {}
  viewResults : Std.HashSet (Nat × Nat) := {}
  loops : Nat := 0
  chanDecls : Std.HashMap String ChanDecl := {}
  chans : Std.HashMap Nat ChanInfo := {}
  /-- The `air.launch` instance being walked. -/
  launchInst : Option (Nat × List Int) := none
  /-- The `air.rank` instance being walked: its start event, the length of the path before its
  point, its point and its sizes (D49). -/
  rankInst : Option (Nat × Nat × List Int × List Int) := none
  /-- Each family of `memref.alloc {air.symmetric}` buffers, one per rank (D49), by the rank
  execution, the alloc and the path outside the rank's point. -/
  families : Std.HashMap (Nat × OperationPtr × List Int) (Array Nat) := {}
  /-- The family and rank of each symmetric buffer. -/
  symOf : Std.HashMap Nat ((Nat × OperationPtr × List Int) × Nat) := {}

abbrev IM := StateT IState (Except String)

def liftE {α : Type} (x : Except String α) : IM α :=
  match x with
  | .ok a => pure a
  | .error e => throw e

/-- A program that instantiates more events than this is refused. -/
def maxEvents : Nat := 20000

def pathStr : List Int → String
  | [] => ""
  | p => s!" (iteration {p})"

def newBufferI (name : String) (t : TypeAttr) : IM Nat := do
  let ty ← liftE (parseMemRefType (typeString t))
  modifyGet fun st => (st.buffers.size, { st with buffers := st.buffers.push { name, type := ty } })

/-- Whether an op carries a discardable unit attribute such as `air.symmetric`. -/
def hasAttrNamed (ctx : IRContext OpCode) (op : OperationPtr) (name : String) : Bool :=
  (op.getAttributes! ctx).entries.any (·.1 == name.toUTF8)

/-- The single rank index of the rank instance being walked (D49). Cross-rank addressing names a
rank by one integer, so only a one-dimensional `air.rank` is supported. -/
def rankIndexSpace (what : String) : IM (Nat × Nat) := do
  let some (_, _, pt, sizes) := (← get).rankInst
    | throw s!"{what}: symmetric memory needs an enclosing air.rank (D49)"
  match pt, sizes with
  | [r], [n] => return (r.toNat, n.toNat)
  | _, _ => throw s!"{what}: symmetric memory in a multi-dimensional air.rank is not supported (a rank is named by one integer)"

/-- The buffer of `memref.alloc {air.symmetric}` for the current rank. The first time any rank
reaches the alloc, the whole family is created, one buffer per rank, so a rank can name a peer's
buffer before that peer has been walked (D49). -/
def symmetricBuffer (alloc : OperationPtr) (name : String) (t : TypeAttr) (path : List Int) : IM Nat := do
  let (r, n) ← rankIndexSpace s!"memref.alloc (air.symmetric){pathStr path}"
  let some (rs, pre, pt, _) := (← get).rankInst | unreachable!
  let key := (rs, alloc, path.take pre ++ path.drop (pre + pt.length))
  if let some fam := (← get).families[key]? then return fam[r]!
  let mut fam := #[]
  for k in [0:n] do
    let b ← newBufferI s!"{name} (symmetric, rank {k})" t
    fam := fam.push b
    modify fun st => { st with symOf := st.symOf.insert b (key, k) }
  modify fun st => { st with families := st.families.insert key fam }
  return fam[r]!

/-- Rank `to`'s buffer of the family `b` belongs to (D49). -/
def peerBuffer (what : String) (b : Nat) (to : Int) : IM Nat := do
  let st ← get
  let some (key, _) := st.symOf[b]?
    | throw s!"{what}: cross-rank access to a buffer not allocated with air.symmetric (D49)"
  let fam := st.families[key]!
  if to < 0 || to.toNat ≥ fam.size then
    throw s!"{what}: rank {to} is outside the air.rank's {fam.size} rank(s)"
  return fam[to.toNat]!

def lookupH (env : Std.HashMap ValuePtr HVal) (ctx : IRContext OpCode) (v : ValuePtr) (what : String) :
    Except String HVal :=
  match env[v]? with
  | some h => pure h
  | none =>
    match v with
    | .opResult ⟨d, _⟩ => throw s!"{what}: uses a value of '{opName ctx d}', which is not supported"
    | .blockArgument _ => throw s!"{what}: uses a block argument the host does not know"

def tokOf (env : Std.HashMap ValuePtr HVal) (ctx : IRContext OpCode) (what : String) (v : ValuePtr) :
    Except String Nat := do
  if let .blockArgument _ := v then
    if !env.contains v then
      throw s!"{what}: a token that is a block argument is not supported; tokens must come from \
        an event the host issues"
  match ← lookupH env ctx v what with
  | .tok e => pure e
  | _ => throw s!"{what}: a dependency operand is not the token of an event"

def knownInt (env : Std.HashMap ValuePtr HVal) (ctx : IRContext OpCode) (what : String) (v : ValuePtr) :
    Except String Int := do
  match ← lookupH env ctx v what with
  | .val x =>
    match x.toInt? with
    | some n => pure n
    | none => throw s!"{what}: a loop bound is not known (does it depend on an argument? pass --args)"
  | _ => throw s!"{what}: a loop bound is computed by an event, which is not supported"

/-- An integer of a value's type. -/
def intVal (ctx : IRContext OpCode) (v : ValuePtr) (n : Int) : Val :=
  let w := match typeString (v.getType! ctx) with
    | "index" => 64
    | t => match t.toList with
      | 'i' :: ds => (String.ofList ds).toNat?.getD 64
      | _ => 64
  .rv (.int w (.val (BitVec.ofInt w n)))

/-- Whether every result of an op is an integer or `index`. -/
def isIntegerResult (ctx : IRContext OpCode) (op : OperationPtr) : Bool :=
  (op.getResultTypes! ctx).all fun t =>
    let s := typeString t
    s == "index" || (s.startsWith "i" && (s.drop 1).toString.toNat?.isSome)

/-- Host arithmetic: computed when its operands are known, `undef` otherwise. -/
def evalHostArith (ctx : IRContext OpCode) (op : OperationPtr) (env : Std.HashMap ValuePtr HVal) :
    Except String (Std.HashMap ValuePtr HVal) := do
  let ins ← (op.getOperands! ctx).toList.mapM fun v => do
    match ← lookupH env ctx v s!"'{opName ctx op}'" with
    | .val x => pure (some x)
    | _ => pure none
  let mut env := env
  match ins.mapM (·.bind toRuntime?) with
  | some rs =>
    match evalArith ctx op rs.toArray with
    | .ok results =>
      for r in results, i in [0:results.size] do
        env := env.insert (.opResult ⟨op, i⟩) (.val (.rv r))
    | .error e =>
      -- VeIR's arith computes on integers only: a float result is an opaque value (D22).
      if !isIntegerResult ctx op then
        for i in [0:op.getNumResults! ctx] do
          env := env.insert (.opResult ⟨op, i⟩) (.val (opaqueOf op [] i))
      else throw e
  | none =>
    for i in [0:op.getNumResults! ctx] do
      env := env.insert (.opResult ⟨op, i⟩) (.val .undef)
  return env

/-- The buffer a memref value names, as far as it is known before running. -/
def staticBuf (st : IState) (h : HVal) : Option Nat :=
  match h with
  | .val (.buf b) => some b
  | .result e i => st.resultBufs[(e, i)]?
  | _ => none

/-- Record an event instance. -/
def pushEvent (e : Event) (c : EventCtx) : IM Nat := do
  let st ← get
  if st.events.size ≥ maxEvents then
    throw s!"more than {maxEvents} event instances; the program is too large to instantiate"
  let id := st.events.size
  let blocking := e.kind == .waitAllBlocking || e.kind == .dmaBlocking ||
    e.kind == .putBlocking || e.kind == .getBlocking || e.kind == .scopeEndBlocking ||
    e.kind == .syncOp
  set { st with events := st.events.push { e with implicitDeps := st.blocking },
                ctxs := st.ctxs.push { c with launchInst := st.launchInst },
                blocking := if blocking then st.blocking ++ [id] else st.blocking }
  return id

/-- What a body (an `air.execute`'s, or the single op of a synchronous op, D45) captures:
the values from outside it, the events whose results it reads, the buffers its allocations
create, and which of its values name buffers or views. -/
structure Captured where
  captured : Std.HashMap ValuePtr HVal
  dataDeps : List Nat
  allocBufs : Std.HashMap OperationPtr Nat
  localBuf : Std.HashMap ValuePtr Nat
  localView : Std.HashSet ValuePtr

def captureBody (ctx : IRContext OpCode) (what : String) (ops : Array OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (id : Nat) (path : List Int) : IM Captured := do
  let mut captured : Std.HashMap ValuePtr HVal := {}
  let mut dataDeps : List Nat := []
  let mut inBody : Std.HashSet OperationPtr := {}
  let mut allocBufs : Std.HashMap OperationPtr Nat := {}
  let mut localBuf : Std.HashMap ValuePtr Nat := {}
  let mut localView : Std.HashSet ValuePtr := {}
  for inner in ops do
    let iname := opName ctx inner
    if iname == "air.execute" then
      throw s!"{what}: an air.execute nested in another is not supported (air-dependency produces it when run on async input, AIR-019)"
    let isOpaque := !(iname.startsWith "arith." || iname.startsWith "memref.") || iname == "memref.copy"
    if inner.getNumRegions! ctx ≠ 0 && !isOpaque then
      throw s!"{what}: '{iname}' has a region, which is not supported"
    -- Values from outside the body, including those an uninterpreted op's regions use.
    let uses := (inner.getOperands! ctx) ++ (if isOpaque then memrefOperands ctx inner else #[])
    for v in uses do
      let isLocal := match v with
        | .opResult ⟨d, _⟩ => inBody.contains d
        | .blockArgument _ => false
      if isLocal || captured.contains v then continue
      match env[v]? with
      | some h =>
        if let .tok _ := h then
          -- air.custom lists its dependencies among its operands (D49).
          if iname == "air.custom" then continue
          throw s!"{what}: '{iname}' uses a token as a value"
        if let .result e _ := h then
          if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
        captured := captured.insert v h
      | none =>
        -- A value defined inside an uninterpreted op's region needs nothing from outside.
        if isOpaque then continue
        match v with
        | .opResult ⟨d, _⟩ => throw s!"{what}: '{iname}' reads a value of '{opName ctx d}', which is not supported"
        | .blockArgument _ => throw s!"{what}: '{iname}' reads a block argument the host does not know"
    if iname == "memref.alloc" then
      let ty := (ValuePtr.opResult ⟨inner, 0⟩).getType! ctx
      let nb ← if hasAttrNamed ctx inner "air.symmetric" then
          symmetricBuffer inner s!"alloc in event {id}{pathStr path}" ty path
        else newBufferI s!"alloc in event {id}{pathStr path}" ty
      allocBufs := allocBufs.insert inner nb
      localBuf := localBuf.insert (.opResult ⟨inner, 0⟩) nb
    else if viewOps.contains iname then
      let src := (inner.getOperands! ctx)[0]!
      let sb := localBuf[src]? <|> (captured[src]? >>= staticBuf (← get))
      if let some sb := sb then localBuf := localBuf.insert (.opResult ⟨inner, 0⟩) sb
      localView := localView.insert (.opResult ⟨inner, 0⟩)
    else if iname == "memref.load" || iname == "memref.store" then
      let m := (inner.getOperands! ctx)[if iname == "memref.load" then 0 else 1]!
      if localView.contains m then throw s!"{what}: '{iname}' through a view is not supported"
    inBody := inBody.insert inner
  return { captured, dataDeps, allocBufs, localBuf, localView }

/-- An op without `async` that is not otherwise an event (`memref.dealloc`, `linalg.*`,
`func.call`, ...): a blocking event whose body is the op itself, so the host issues nothing after
it until it finished (D45). Its results are available once it finished, as an `air.execute`'s. -/
def syncOpInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"'{opName ctx op}'{pathStr path}"
  let id := (← get).events.size
  let cap ← captureBody ctx what #[op] env id path
  let yields := (List.range (op.getNumResults! ctx)).toArray.map fun i => ValuePtr.opResult ⟨op, i⟩
  let ev : Event := { op := op, kind := .syncOp, operandEvents := #[], implicitDeps := [],
                      dataDeps := cap.dataDeps, body := #[op], yields := yields }
  let _ ← pushEvent ev { env := cap.captured, allocBufs := cap.allocBufs, path := path }
  let mut out := env
  for y in yields, i in [0:yields.size] do
    out := out.insert y (.result id (i + 1))
    if let some b := cap.localBuf[y]? then
      modify fun st => { st with resultBufs := st.resultBufs.insert (id, i + 1) b }
    if cap.localView.contains y then
      modify fun st => { st with viewResults := st.viewResults.insert (id, i + 1) }
  return out

/-- The integer a host value is, if it is known. -/
def knownIntH? (h : HVal) : Option Int :=
  match h with
  | .val x => x.toInt?
  | _ => none

/-- An affine attribute's text (kept verbatim by VeIR's parser). -/
def affineText (ctx : IRContext OpCode) (op : OperationPtr) (prop : String) : Option String :=
  match findProp (unregProps ctx op) prop with
  | some (.unregisteredAttr u) => some u.value
  | _ => none

/-- `affine.apply`: evaluated when its operands are known, `undef` otherwise. The map's dims
come first among the operands, then its symbols. -/
def affineApply (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"affine.apply{pathStr path}"
  let some map := affineText ctx op "map" | throw s!"{what}: missing map"
  let ins ← (op.getOperands! ctx).toList.mapM fun v => liftE (lookupH env ctx v what)
  let res := ValuePtr.opResult ⟨op, 0⟩
  match ins.mapM knownIntH? with
  | none => return env.insert res (.val .undef)
  | some ns =>
    let nDims := Affine.numDims "affine_map" map
    match Affine.evalMap map (ns.take nDims) (ns.drop nDims) with
    | .ok [v] => return env.insert res (.val (intVal ctx res v))
    | .ok _ => throw s!"{what}: expected a map with one result"
    | .error e => throw s!"{what}: {e}"

/-- Which region of `scf.if`, `affine.if` or `scf.index_switch` runs (`none`: no region, as in
an `scf.if` without `else` whose condition is false). The choice must be known before running:
a branch on a runtime value is refused. -/
def chosenRegion (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (what : String) : IM (Option Nat) := do
  let name := opName ctx op
  let ins ← (op.getOperands! ctx).toList.mapM fun v => liftE (lookupH env ctx v what)
  let unknown := s!"{what}: the branch condition is not known before running (a branch on a runtime value is not supported)"
  if name == "scf.if" then
    let some c := ins.head? >>= knownIntH? | throw unknown
    return if c != 0 then some 0 else some 1
  else if name == "affine.if" then
    let some set := affineText ctx op "condition" | throw s!"{what}: missing condition"
    let some ns := ins.mapM knownIntH? | throw unknown
    let nDims := Affine.numDims "affine_set" set
    match Affine.evalSet set (ns.take nDims) (ns.drop nDims) with
    | .ok b => return if b then some 0 else some 1
    | .error e => throw s!"{what}: {e}"
  else
    -- scf.index_switch: region 0 is the default, region i + 1 the i-th case.
    let some a := ins.head? >>= knownIntH? | throw unknown
    let cases := (denseInts (findProp (unregProps ctx op) "cases")).getD #[]
    match cases.toList.findIdx? (· == a) with
    | some i => return some (i + 1)
    | none => return some 0

/-- Ops that are control flow or address arithmetic, not effects: never a synchronous op. -/
def notSyncOp (name : String) : Bool :=
  ["scf.", "affine.", "air.", "cf."].any fun (p : String) => name.startsWith p

/-- `air.translate %src, %from, %to, %bases`: rank `%to`'s buffer of `%src`'s family; `%src` must
be rank `%from`'s (D49). The heap bases are a runtime detail and play no part. -/
def translateInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"air.translate{pathStr path}"
  let ops := op.getOperands! ctx
  if ops.size != 4 then throw s!"{what}: expected 4 operands"
  let src ← liftE (lookupH env ctx ops[0]! what)
  let fromR ← liftE (knownInt env ctx s!"{what} (from rank)" ops[1]!)
  let toR ← liftE (knownInt env ctx s!"{what} (to rank)" ops[2]!)
  let some b := staticBuf (← get) src | throw s!"{what}: the source does not name a buffer the model knows"
  let some (_, k) := (← get).symOf[b]?
    | throw s!"{what}: the source is not allocated with air.symmetric (D49)"
  if (k : Int) != fromR then
    throw s!"{what}: the source is rank {k}'s buffer, not rank {fromR}'s (undefined, D49)"
  let pb ← peerBuffer what b toR
  return env.insert (.opResult ⟨op, 0⟩) (.val (.buf pb))

/-- `air.custom`: a user op, an event like an `air.execute` whose body is the op itself. It reads
and writes each memref operand whole and its values are opaque (D22); with a result it is async
and waits for its dependencies, without one it is blocking (D49). -/
def customInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"air.custom{pathStr path}"
  let some seg := denseInts (findProp (unregProps ctx op) "operandSegmentSizes")
    | throw s!"{what}: missing operandSegmentSizes"
  let nDeps := (seg[0]?.getD 0).toNat
  let deps ← ((op.getOperands! ctx).extract 0 nDeps).toList.mapM fun v => liftE (tokOf env ctx what v)
  let id := (← get).events.size
  let cap ← captureBody ctx what #[op] env id path
  let blocking := op.getNumResults! ctx = 0
  let ev : Event := { op := op, kind := if blocking then .syncOp else .execute,
                      operandEvents := deps.toArray, implicitDeps := [], dataDeps := cap.dataDeps,
                      body := #[op], yields := #[] }
  let _ ← pushEvent ev { env := cap.captured, allocBufs := cap.allocBufs, path := path }
  if blocking then return env
  return env.insert (.opResult ⟨op, 0⟩) (.tok id)

/-- The hierarchy ops (layer 5). -/
def hierarchyOps : List String := ["air.launch", "air.segment", "air.herd", "air.rank"]

/-- Every point of an iteration space, outermost dimension first. -/
def iterationPoints (sizes : List Int) : List (List Int) :=
  sizes.foldr (init := [[]]) fun n acc =>
    (List.range n.toNat).flatMap fun (k : Nat) => acc.map fun rest => (k : Int) :: rest

mutual

/-- Walk a block's operations (without its terminator) as the host does. -/
partial def walkOps (ctx : IRContext OpCode) (ops : Array OperationPtr)
    (env₀ : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let mut env := env₀
  for op in ops do
    let name := opName ctx op
    let what := s!"'{name}'{pathStr path}"
    match op.getOpType! ctx with
    | .air .execute => env ← executeInstance ctx op env path
    | .air .wait_all =>
      let deps ← (op.getOperands! ctx).toList.mapM fun v => liftE (tokOf env ctx what v)
      let kind := if op.getNumResults! ctx = 0 then EventKind.waitAllBlocking else EventKind.waitAll
      let ev : Event := { op := op, kind := kind, operandEvents := deps.toArray, implicitDeps := [],
                          dataDeps := [], body := #[], yields := #[] }
      let id ← pushEvent ev { path := path }
      if op.getNumResults! ctx = 1 then env := env.insert (.opResult ⟨op, 0⟩) (.tok id)
    | .arith _ => env ← evalHostArith ctx op env
    | .func .return => pure ()
    | .builtin .unregistered =>
      if name == "air.dma_memcpy_nd" then env ← dmaInstance ctx op env path
      else if name == "air.channel.put" then env ← channelInstance ctx op env path true
      else if name == "air.channel.get" then env ← channelInstance ctx op env path false
      else if name == "memref.alloc" then
        let ty := (ValuePtr.opResult ⟨op, 0⟩).getType! ctx
        let b ← if hasAttrNamed ctx op "air.symmetric" then
            symmetricBuffer op s!"host alloc{pathStr path}" ty path
          else newBufferI s!"host alloc{pathStr path}" ty
        env := env.insert (.opResult ⟨op, 0⟩) (.val (.buf b))
      else if name == "scf.for" then env ← forLoop ctx op env path
      else if name == "scf.parallel" then env ← parallelLoop ctx op env path
      else if hierarchyOps.contains name then env ← hierarchyInstance ctx op env path
      else if name == "air.translate" then env ← translateInstance ctx op env path
      else if name == "air.custom" then env ← customInstance ctx op env path
      else if name == "affine.apply" then env ← affineApply ctx op env path
      else if name == "veir.opaque_constant" then
        -- A non-integer constant (VEIR-004): an opaque value (D22).
        env := env.insert (.opResult ⟨op, 0⟩) (.val (opaqueOf op [] 0))
      else if name == "scf.if" || name == "affine.if" || name == "scf.index_switch" then
        env ← branchInstance ctx op env path
      else if name == "air.universe.alloc" then
        -- The pool `air.rank` instances are placed in: a resource, not modelled.
        env := env.insert (.opResult ⟨op, 0⟩) (.val .undef)
      else if notSyncOp name then
        if op.getNumRegions! ctx ≠ 0 then
          throw s!"{what}: '{name}' opens a nested region or scope, which is not supported"
        else throw s!"{what}: '{name}' is not supported in a function body"
      else if op.getNumRegions! ctx ≠ 0 && !name.startsWith "linalg." then
        throw s!"{what}: '{name}' opens a nested region or scope, which is not supported"
      else env ← syncOpInstance ctx op env path
    | .func .call => env ← syncOpInstance ctx op env path
    | _ =>
      if op.getNumRegions! ctx ≠ 0 then
        throw s!"{what}: '{name}' opens a nested region or scope, which is not supported"
      throw s!"{what}: '{name}' is not supported in a function body"
  return env

/-- An `air.execute` instance. -/
partial def executeInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"air.execute{pathStr path}"
  let deps ← (op.getOperands! ctx).toList.mapM fun v => liftE (tokOf env ctx what v)
  let b ← liftE (singleBlock ctx op what)
  let bops := blockOps ctx b
  let some term := bops.back? | throw s!"{what}: expected a terminator"
  let .air .execute_terminator := term.getOpType! ctx
    | throw s!"{what}: expected the body to end in air.execute_terminator"
  let body := bops.pop
  let id := (← get).events.size
  let cap ← captureBody ctx what (body ++ #[term]) env id path
  let captured := cap.captured
  let dataDeps := cap.dataDeps
  let allocBufs := cap.allocBufs
  let localBuf := cap.localBuf
  let localView := cap.localView
  let yields := term.getOperands! ctx
  let results := op.getResultTypes! ctx
  if yields.size + 1 ≠ results.size then
    throw s!"{what}: the terminator yields {yields.size} value(s), but the operation declares {results.size - 1}"
  for i in [0:yields.size] do
    if (term.getOperandTypes! ctx)[i]! != results[i + 1]! then
      throw s!"{what}: the terminator yields {(term.getOperandTypes! ctx)[i]!} as value #{i}, but the operation declares {results[i + 1]!}"
  let ev : Event := { op := op, kind := .execute, operandEvents := deps.toArray, implicitDeps := [],
                      dataDeps := dataDeps, body := body, yields := yields }
  let _ ← pushEvent ev { env := captured, allocBufs := allocBufs, path := path }
  let mut out := env.insert (.opResult ⟨op, 0⟩) (.tok id)
  for y in yields, i in [0:yields.size] do
    out := out.insert (.opResult ⟨op, i + 1⟩) (.result id (i + 1))
    let yb := localBuf[y]? <|> (captured[y]? >>= staticBuf (← get))
    if let some yb := yb then
      modify fun st => { st with resultBufs := st.resultBufs.insert (id, i + 1) yb }
    if localView.contains y then
      modify fun st => { st with viewResults := st.viewResults.insert (id, i + 1) }
  return out

/-- An `air.dma_memcpy_nd` instance. -/
partial def dmaInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"air.dma_memcpy_nd{pathStr path}"
  let props := unregProps ctx op
  let rankOf (n : String) : Option Int := match findProp props n with
    | some (.integerAttr i) => some i.value
    | _ => none
  let srcRank := rankOf "src_rank"
  let dstRank := rankOf "dst_rank"
  let info ← liftE (decodeDma ctx op)
  let nDeps := ((denseInts (findProp (unregProps ctx op) "operandSegmentSizes")).getD #[0])[0]!.toNat
  let operands := op.getOperands! ctx
  let deps ← (operands.extract 0 nDeps).toList.mapM fun v => liftE (tokOf env ctx what v)
  let mut captured : Std.HashMap ValuePtr HVal := {}
  let mut dataDeps : List Nat := []
  for v in operands.extract nDeps operands.size do
    let h ← liftE (lookupH env ctx v what)
    if let .tok _ := h then throw s!"{what}: a token used as a DMA operand"
    if let .result e _ := h then
      if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
    captured := captured.insert v h
  -- A cross-rank side addresses that rank's buffer of the family (D49).
  if (srcRank.isSome || dstRank.isSome) && info.src.memref == info.dst.memref && srcRank != dstRank then
    throw s!"{what}: one memref on both sides with different ranks is not supported"
  for (m, r?) in [(info.src.memref, srcRank), (info.dst.memref, dstRank)] do
    if let some r := r? then
      let _ ← rankIndexSpace what
      let some b := staticBuf (← get) captured[m]! | throw s!"{what}: the DMA's memref does not name a buffer the model knows"
      let pb ← peerBuffer what b r
      captured := captured.insert m (.val (.buf pb))
  for m in [info.dst.memref, info.src.memref] do
    let st ← get
    if let .result e i := captured[m]! then
      if st.viewResults.contains (e, i) then
        throw s!"{what}: a DMA on a view is not supported; fold the view into the pattern first"
    if (staticBuf st captured[m]!).isNone then
      throw s!"{what}: the DMA's memref does not name a buffer the model knows"
  let blocking := op.getNumResults! ctx = 0
  let ev : Event := { op := op, kind := if blocking then .dmaBlocking else .dma,
                      operandEvents := deps.toArray, implicitDeps := [], dataDeps := dataDeps,
                      body := #[], yields := #[] }
  let id ← pushEvent ev { env := captured, path := path }
  modify fun st => { st with dmas := st.dmas.insert id info }
  if !blocking then return env.insert (.opResult ⟨op, 0⟩) (.tok id)
  return env

/-- An `air.channel.put` or `air.channel.get` instance (layer 4). -/
partial def channelInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) (isPut : Bool) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"{opName ctx op}{pathStr path}"
  let props := unregProps ctx op
  let some seg := denseInts (findProp props "operandSegmentSizes")
    | throw s!"{what}: missing operandSegmentSizes"
  if seg.size != (if isPut then 7 else 6) then throw s!"{what}: unexpected operand segments"
  let operands := op.getOperands! ctx
  let mut groups : Array (Array ValuePtr) := #[]
  let mut start := 0
  for n in seg do
    groups := groups.push (operands.extract start (start + n.toNat))
    start := start + n.toNat
  let some (.flatSymbolRefAttr chanRef) := findProp props "chan_name"
    | throw s!"{what}: missing chan_name"
  -- The symbol is stored as written, with its `@`.
  let chan := if chanRef.value.startsWith "@" then (chanRef.value.drop 1).toString else chanRef.value
  if !(← get).chanDecls.contains chan then
    throw s!"{what}: no air.channel @{chan} is declared in the module"
  let deps ← groups[0]!.toList.mapM fun v => liftE (tokOf env ctx what v)
  let indices₀ ← groups[1]!.toList.mapM fun v => liftE (knownInt env ctx s!"{what} (channel index)" v)
  -- D50: on a channel whose every dimension has size 1, no indices name subchannel [0, ..., 0].
  let size := (← get).chanDecls[chan]!.size
  let indices := if indices₀.isEmpty && size.all (· == 1) then size.map fun _ => (0 : Int) else indices₀
  let some memref := groups[2]!.toList.head? | throw s!"{what}: no memref"
  let pre := if isPut then "src" else "dst"
  let arr (name : String) : IM (Array Int) :=
    match denseInts (findProp props name) with
    | some a => pure a
    | none => throw s!"{what}: missing {name}"
  let offs ← liftE (decodeList (← arr s!"static_{pre}_offsets") groups[3]!)
  let szs ← liftE (decodeList (← arr s!"static_{pre}_sizes") groups[4]!)
  let strs ← liftE (decodeList (← arr s!"static_{pre}_strides") groups[5]!)
  let side : DmaSide := { memref := memref, offsets := offs, sizes := szs, strides := strs }
  let dest ← if isPut && seg[6]! > 0 then
      some <$> liftE (knownInt env ctx s!"{what} (dest)" groups[6]![0]!)
    else pure none
  let padBefore := (denseInts (findProp props "pad_before")).getD #[]
  let padAfter := (denseInts (findProp props "pad_after")).getD #[]
  if padBefore.size != padAfter.size then throw s!"{what}: pad_before and pad_after differ in rank"
  let mut captured : Std.HashMap ValuePtr HVal := {}
  let mut dataDeps : List Nat := []
  for v in #[memref] ++ groups[3]! ++ groups[4]! ++ groups[5]! do
    let h ← liftE (lookupH env ctx v what)
    if let .tok _ := h then throw s!"{what}: a token used as an operand"
    if let .result e _ := h then
      if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
    captured := captured.insert v h
  let st ← get
  if let .result e i := captured[memref]! then
    if st.viewResults.contains (e, i) then
      throw s!"{what}: a channel endpoint on a view is not supported; fold the view into the pattern first"
  if (staticBuf st captured[memref]!).isNone then
    throw s!"{what}: the memref does not name a buffer the model knows"
  let blocking := op.getNumResults! ctx = 0
  let kind : EventKind :=
    if isPut then (if blocking then .putBlocking else .put)
    else (if blocking then .getBlocking else .get)
  let ev : Event := { op := op, kind := kind, operandEvents := deps.toArray, implicitDeps := [],
                      dataDeps := dataDeps, body := #[], yields := #[] }
  let id ← pushEvent ev { env := captured, path := path }
  let info : ChanInfo := { chan := chan, isPut := isPut, indices := indices, side := side,
                           padBefore := padBefore, padAfter := padAfter, dest := dest }
  modify fun st => { st with chans := st.chans.insert id info }
  if !blocking then return env.insert (.opResult ⟨op, 0⟩) (.tok id)
  return env

/-- An `air.launch`, `air.segment`, `air.herd` or `air.rank` (layer 5, D37-D43): a start event
carrying its dependencies, then the body once per point of its iteration space, then an end event
that waits for every event inside (its token). Inside an instance:
- every event waits for the start event, and a blocking op blocks only that instance (D39);
- each `memref.alloc` makes a new buffer, so allocations are private to the instance (D40);
- kernel operands are the outer values themselves: memrefs by reference, tokens as the outer
  events (D40, D42). The body is isolated from above, so nothing else is visible. -/
partial def hierarchyInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let name := opName ctx op
  let what := s!"'{name}'{pathStr path}"
  let props := unregProps ctx op
  if (findProp props "affinity").isSome || (findProp props "concurrency").isSome then
    throw s!"{what}: affinity/concurrency token lists are not implemented in AIR (D44)"
  let isRank := name == "air.rank"
  let some seg := denseInts (findProp props "operandSegmentSizes")
    | throw s!"{what}: missing operandSegmentSizes"
  if seg.size != (if isRank then 4 else 3) then throw s!"{what}: unexpected operand segments"
  let nDeps := seg[0]!.toNat
  let nUni := if isRank then seg[1]!.toNat else 0
  let nSizes := seg[if isRank then 2 else 1]!.toNat
  let operands := op.getOperands! ctx
  let deps ← (operands.extract 0 nDeps).toList.mapM fun v => liftE (tokOf env ctx what v)
  let sizes ← (operands.extract (nDeps + nUni) (nDeps + nUni + nSizes)).toList.mapM fun v =>
    liftE (knownInt env ctx s!"{what} (size)" v)
  let kernel ← (operands.extract (nDeps + nUni + nSizes) operands.size).toList.mapM fun v =>
    liftE (lookupH env ctx v what)
  let block ← liftE (singleBlock ctx op what)
  let args := block.getArguments! ctx
  if args.size != 2 * nSizes + kernel.length then
    throw s!"{what}: expected {2 * nSizes + kernel.length} block arguments, found {args.size}"
  let ops := blockOps ctx block
  let some term := ops.back? | throw s!"{what}: expected a terminator"
  if !(opName ctx term).endsWith "_terminator" then throw s!"{what}: expected a terminator"
  let startEv : Event := { op := op, kind := .scopeStart, operandEvents := deps.toArray,
                           implicitDeps := [], dataDeps := [], body := #[], yields := #[] }
  let start ← pushEvent startEv { path := path }
  let outer ← get
  let mut inner : Array Nat := #[start]
  for pt in iterationPoints sizes do
    modify fun st => { st with
      blocking := [start],
      launchInst := if name == "air.launch" then some (start, pt) else st.launchInst,
      rankInst := if isRank then some (start, path.length, pt, sizes) else st.rankInst }
    let first := (← get).events.size
    let mut env' : Std.HashMap ValuePtr HVal := {}
    for a in args.toList.take nSizes, i in pt do
      env' := env'.insert a (.val (intVal ctx a i))
    for a in (args.toList.drop nSizes).take nSizes, n in sizes do
      env' := env'.insert a (.val (intVal ctx a n))
    for a in args.toList.drop (2 * nSizes), h in kernel do
      env' := env'.insert a h
    let _ ← walkOps ctx ops.pop env' (path ++ pt)
    inner := inner ++ (List.range' first ((← get).events.size - first)).toArray
  modify fun st => { st with blocking := outer.blocking, launchInst := outer.launchInst,
                              rankInst := outer.rankInst }
  let blocking := op.getNumResults! ctx = 0
  let endEv : Event := { op := op, kind := if blocking then .scopeEndBlocking else .scopeEnd,
                         operandEvents := inner, implicitDeps := [], dataDeps := [],
                         body := #[], yields := #[] }
  let fin ← pushEvent endEv { path := path }
  if !blocking then return env.insert (.opResult ⟨op, 0⟩) (.tok fin)
  return env

/-- `scf.if`, `affine.if`, `scf.index_switch`: the host runs the region the (known) condition
selects, as upstream MLIR does; its results are what that region yields. -/
partial def branchInstance (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"'{opName ctx op}'{pathStr path}"
  let some r ← chosenRegion ctx op env what | return env
  if r ≥ op.getNumRegions! ctx then
    if op.getNumResults! ctx = 0 then return env
    throw s!"{what}: the chosen region does not exist"
  let some block := (op.getRegion! ctx r).getFirstBlock! ctx
    | if op.getNumResults! ctx = 0 then return env else throw s!"{what}: the chosen region is empty"
  let ops := blockOps ctx block
  let some term := ops.back? | throw s!"{what}: expected a terminator"
  let inner ← walkOps ctx ops.pop env path
  let ys ← (term.getOperands! ctx).toList.mapM fun v => liftE (lookupH inner ctx v what)
  let mut out := env
  for i in [0:op.getNumResults! ctx], h in ys do
    out := out.insert (.opResult ⟨op, i⟩) h
  return out

/-- `scf.for`: iterations in order; only the tokens `iter_args` carry order them (D26). -/
partial def forLoop (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"scf.for{pathStr path}"
  let operands := op.getOperands! ctx
  if operands.size < 3 then throw s!"{what}: expected bounds and a step"
  let lb ← liftE (knownInt env ctx what operands[0]!)
  let ub ← liftE (knownInt env ctx what operands[1]!)
  let step ← liftE (knownInt env ctx what operands[2]!)
  if step ≤ 0 then throw s!"{what}: a step of {step} is not supported"
  let block ← liftE (singleBlock ctx op what)
  let args := block.getArguments! ctx
  let ops := blockOps ctx block
  let some term := ops.back? | throw s!"{what}: expected a terminator"
  if opName ctx term != "scf.yield" then throw s!"{what}: expected the body to end in scf.yield"
  let mut iter ← (operands.extract 3 operands.size).toList.mapM fun v =>
    liftE (lookupH env ctx v what)
  modify fun st => { st with loops := st.loops + 1 }
  let trips := if ub > lb then ((ub - lb + step - 1) / step).toNat else 0
  for k in [0:trips] do
    let iv := lb + k * step
    let mut env' := env.insert args[0]! (.val (intVal ctx args[0]! iv))
    for a in args.toList.drop 1, h in iter do
      env' := env'.insert a h
    env' ← walkOps ctx ops.pop env' (path ++ [iv])
    iter ← (term.getOperands! ctx).toList.mapM fun v => liftE (lookupH env' ctx v what)
  let mut out := env
  for i in [0:op.getNumResults! ctx], h in iter do
    out := out.insert (.opResult ⟨op, i⟩) h
  return out

/-- `scf.parallel`: every iteration concurrent; the result is the reduction of the iterations'
values, folded in iteration order (D27). -/
partial def parallelLoop (ctx : IRContext OpCode) (op : OperationPtr)
    (env : Std.HashMap ValuePtr HVal) (path : List Int) : IM (Std.HashMap ValuePtr HVal) := do
  let what := s!"scf.parallel{pathStr path}"
  let some seg := denseInts (findProp (unregProps ctx op) "operandSegmentSizes")
    | throw s!"{what}: missing operandSegmentSizes"
  if seg.size != 4 then throw s!"{what}: expected 4 operand segments"
  let n := seg[0]!.toNat
  let operands := op.getOperands! ctx
  let ints (start : Nat) : IM (List Int) :=
    (operands.extract start (start + n)).toList.mapM fun v => liftE (knownInt env ctx what v)
  let lbs ← ints 0
  let ubs ← ints n
  let steps ← ints (2 * n)
  if steps.any (· ≤ 0) then throw s!"{what}: a non-positive step is not supported"
  let inits ← (operands.extract (3 * n) operands.size).toList.mapM fun v =>
    liftE (lookupH env ctx v what)
  let block ← liftE (singleBlock ctx op what)
  let args := block.getArguments! ctx
  let ops := blockOps ctx block
  let some term := ops.back? | throw s!"{what}: expected a terminator"
  if opName ctx term != "scf.reduce" then throw s!"{what}: expected the body to end in scf.reduce"
  modify fun st => { st with loops := st.loops + 1 }
  -- Every point of the iteration space, outermost dimension first.
  let points : List (List Int) :=
    (lbs.zip (ubs.zip steps)).foldr (init := [[]]) fun (lb, ub, st) acc =>
      let trips := if ub > lb then ((ub - lb + st - 1) / st).toNat else 0
      (List.range trips).flatMap fun (k : Nat) => acc.map fun rest => (lb + (k : Int) * st) :: rest
  let mut reduced : List (List HVal) := []
  for pt in points do
    let mut env' := env
    for a in args, iv in pt do
      env' := env'.insert a (.val (intVal ctx a iv))
    env' ← walkOps ctx ops.pop env' (path ++ pt)
    let vs ← (term.getOperands! ctx).toList.mapM fun v => liftE (lookupH env' ctx v what)
    reduced := reduced ++ [vs]
  -- Fold each reduction region over the iterations' values.
  let mut acc := inits
  for vs in reduced do
    let mut next := []
    for j in [0:acc.length], a in acc, r in vs do
      let rb ← liftE (singleBlock ctx term s!"{what} reduction")
      let rb := if j = 0 then rb else
        match (term.getRegion! ctx j).getFirstBlock! ctx with | some b => b | none => rb
      let rargs := rb.getArguments! ctx
      let rops := blockOps ctx rb
      let some rterm := rops.back? | throw s!"{what}: expected scf.reduce.return"
      let mut renv := env.insert rargs[0]! a
      renv := renv.insert rargs[1]! r
      renv ← walkOps ctx rops.pop renv path
      next := next ++ [← liftE (lookupH renv ctx (rterm.getOperands! ctx)[0]! what)]
    acc := next
  let mut out := env
  for i in [0:op.getNumResults! ctx], h in acc do
    out := out.insert (.opResult ⟨op, i⟩) h
  return out

end

/-- Instantiate a function, with the given scalar arguments (others are unknown). -/
def instantiate (ctx : IRContext OpCode) (func : OperationPtr) (scalarArgs : List Int) :
    Except String IProgram := do
  let .func .func := func.getOpType! ctx
    | throw s!"expected a func.func, but got '{opName ctx func}'"
  let block ← singleBlock ctx func "func.func"
  let ops := blockOps ctx block
  -- The module's `air.channel` declarations.
  let mut decls : Std.HashMap String ChanDecl := {}
  if let some m := func.getParentOp! ctx then
    if let some mb := (m.getRegion! ctx 0).getFirstBlock! ctx then
      for d in blockOps ctx mb do
        if opName ctx d == "air.channel" then
          let props := unregProps ctx d
          let some (.stringAttr nm) := findProp props "sym_name" | continue
          let ints (a : Option Attribute) : Option (List Nat) := match a with
            | some (.arrayAttr arr) => arr.value.toList.mapM fun
                | .integerAttr i => some i.value.toNat
                | _ => none
            | _ => none
          let size := (ints (findProp props "size")).getD []
          let attrs := (d.getAttributes! ctx).entries
          let broadcast := ints ((attrs.find? (·.1 == "broadcast_shape".toUTF8)).map (·.2))
          let type := match findProp props "channel_type" with
            | some (.stringAttr t) => String.fromUTF8! t.value
            | _ => "npu_dma_stream"
          let name := String.fromUTF8! nm.value
          decls := decls.insert name { name, size, broadcast, type }
  let go : IM (Std.HashMap ValuePtr HVal × Array Nat) := do
    modify fun st => { st with chanDecls := decls }
    let mut env : Std.HashMap ValuePtr HVal := {}
    let mut argBufs := #[]
    let mut scalars := scalarArgs
    for v in block.getArguments! ctx, i in [0:block.getNumArguments! ctx] do
      let t := v.getType! ctx
      if Air.isAsyncToken t.val then
        -- A token passed in has no event the model knows: `tokOf` refuses its uses.
        continue
      if isMemRefType t then
        let b ← newBufferI s!"%arg{i}" t
        argBufs := argBufs.push b
        env := env.insert v (.val (.buf b))
      else
        match scalars with
        | n :: rest => env := env.insert v (.val (intVal ctx v n)); scalars := rest
        | [] => env := env.insert v (.val .undef)
    let final ← walkOps ctx ops env []
    return (final, argBufs)
  let ((_, argBufs), st) ← go.run {}
  let prog : Program := { func, events := st.events, hostOps := #[] }
  return { prog, ctxs := st.ctxs, buffers := st.buffers, dmas := st.dmas,
           resultBufs := st.resultBufs, viewResults := st.viewResults, argBufs, loops := st.loops,
           chanDecls := st.chanDecls, chans := st.chans }

/-! ### Running -/

structure MState where
  results : Std.HashMap (Nat × Nat) Val := {}
  mem : Std.HashMap (Nat × Int) Val := {}
  freed : Std.HashSet Nat := {}
  fault : Option String := none
deriving Inhabited

def MState.resolve (s : MState) (h : HVal) : Option Val :=
  match h with
  | .val v => some v
  | .result e i => s.results[(e, i)]?
  | .tok _ => none

/-- Memref arguments hold `1000 · argument + element` (integers) or an opaque value. -/
def IProgram.initState (ip : IProgram) : MState := Id.run do
  let mut mem := {}
  for b in ip.argBufs, j in [0:ip.argBufs.size] do
    let t := ip.buffers[b]!.type
    for q in [0:t.numel] do
      let x : Val := if t.bitwidth > 0 then .rv (.int t.bitwidth (.val (BitVec.ofInt t.bitwidth (1000 * j + q))))
        else .opaque 1000000 (1000 * j + q).toUInt64
      mem := mem.insert (b, (q : Int)) x
  return { mem }

def IProgram.finishDma (ip : IProgram) (v : Nat) (s : MState) : MState := Id.run do
  let fail (m : String) : MState := { s with fault := some s!"event {v} (air.dma_memcpy_nd{pathStr ip.ctxs[v]!.path}): {m}" }
  let some info := ip.dmas[v]? | return fail "no DMA information"
  let c := ip.ctxs[v]!
  let res (vp : ValuePtr) : Option Val := c.env[vp]? >>= s.resolve
  let entries (xs : Array (Int ⊕ ValuePtr)) : Option (Array Int) :=
    xs.mapM fun | .inl n => some n | .inr vp => res vp >>= Val.toInt?
  let some (.buf sb) := res info.src.memref | return fail "its source buffer is not available"
  let some (.buf db) := res info.dst.memref | return fail "its destination buffer is not available"
  if s.freed.contains sb || s.freed.contains db then return fail "a buffer it uses was deallocated"
  let st := ip.buffers[sb]!.type
  let dt := ip.buffers[db]!.type
  let some so := entries info.src.offsets | return fail "a source offset is not known"
  let some sz := entries info.src.sizes | return fail "a source size is not known"
  let some ss := entries info.src.strides | return fail "a source stride is not known"
  let some dO := entries info.dst.offsets | return fail "a destination offset is not known"
  let some dz := entries info.dst.sizes | return fail "a destination size is not known"
  let some ds := entries info.dst.strides | return fail "a destination stride is not known"
  match (do
      let sdims ← sidePositions st so sz ss
      let ddims ← sidePositions dt dO dz ds
      let stream ← srcStream sdims info.padBefore info.padAfter
      let dpos := positions ddims
      if stream.length != dpos.length then
        throw s!"the source stream has {stream.length} element(s) but the destination pattern {dpos.length} (D20)"
      checkBounds st ip.buffers[sb]!.name (stream.filterMap id)
      checkBounds dt ip.buffers[db]!.name dpos
      pure (stream, dpos) : Except String _) with
  | .error m => return fail m
  | .ok (stream, dpos) =>
    -- Read the whole stream, then write it in order (D21).
    let vals := stream.map fun
      | some p => s.mem[(sb, p)]?.getD .undef
      | none => zeroOf st
    let mut mem := s.mem
    for p in dpos, x in vals do
      mem := mem.insert (db, p) x
    return { s with mem }

/-- The buffers an uninterpreted op writes: a linalg op's `outs`, `memref.copy`'s target, and
otherwise every memref it touches (D22). -/
def writtenBuffers (ctx : IRContext OpCode) (inner : OperationPtr) (bufOf : ValuePtr → Option Nat) :
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

def IProgram.finishExecute (ctx : IRContext OpCode) (ip : IProgram) (v : Nat) (s : MState) : MState := Id.run do
  let c := ip.ctxs[v]!
  let e := ip.prog.events[v]!
  let fail (m : String) : MState := { s with fault := some s!"event {v}{pathStr c.path}: {m}" }
  let mut vals : Std.HashMap ValuePtr Val := {}
  let mut mem := s.mem
  let mut freed := s.freed
  for inner in e.body do
    let iname := opName ctx inner
    let operands := inner.getOperands! ctx
    let mut ins := #[]
    for o in operands do
      if Air.isAsyncToken (o.getType! ctx).val then continue
      match vals[o]? with
      | some x => ins := ins.push x
      | none =>
        match c.env[o]? with
        | some h =>
          match s.resolve h with
          | some x => ins := ins.push x
          | none =>
            let src := match h with | .result e' _ => s!"event {e'}" | _ => "a token"
            return fail s!"'{iname}' read a result of {src} before it was available"
        | none => return fail s!"'{iname}' read a value that is not available"
    let lookup (m : ValuePtr) : Option Val := vals[m]? <|> (c.env[m]? >>= s.resolve)
    let bufOfVal (x : Val) : Option Nat := match x with | .buf b => some b | _ => none
    let position (b : Nat) (idx : Array Val) : Except String Int := do
      let t := ip.buffers[b]!.type
      if idx.size != t.shape.length then throw "wrong number of indices"
      let mut q : Int := 0
      for i in idx, d in t.shape, stv in t.strides do
        let some n := i.toInt? | throw "an index is not a known integer"
        if n < 0 || n ≥ d then throw s!"index {n} is outside a dimension of size {d}"
        q := q + n * stv
      return q
    if iname == "memref.alloc" then
      if let some b := c.allocBufs[inner]? then
        vals := vals.insert (.opResult ⟨inner, 0⟩) (.buf b)
        freed := freed.erase b
    else if viewOps.contains iname then
      if let some x := ins[0]? then vals := vals.insert (.opResult ⟨inner, 0⟩) x
    else if iname == "memref.dealloc" then
      let some b := ins[0]? >>= bufOfVal | return fail "memref.dealloc of an unknown buffer"
      if freed.contains b then return fail s!"{ip.buffers[b]!.name} deallocated twice"
      freed := freed.insert b
    else if iname == "memref.load" then
      let some b := ins[0]? >>= bufOfVal | return fail "memref.load of an unknown buffer"
      if freed.contains b then return fail s!"memref.load after {ip.buffers[b]!.name} was deallocated"
      match position b (ins.extract 1 ins.size) with
      | .error m => return fail s!"memref.load: {m}"
      | .ok q => vals := vals.insert (.opResult ⟨inner, 0⟩) (mem[(b, q)]?.getD .undef)
    else if iname == "memref.store" then
      let some b := ins[1]? >>= bufOfVal | return fail "memref.store to an unknown buffer"
      if freed.contains b then return fail s!"memref.store after {ip.buffers[b]!.name} was deallocated"
      match position b (ins.extract 2 ins.size) with
      | .error m => return fail s!"memref.store: {m}"
      | .ok q => mem := mem.insert (b, q) ins[0]!
    else if iname.startsWith "arith." then
      match ins.toList.mapM toRuntime? with
      | some rs =>
        match evalArith ctx inner rs.toArray with
        | .ok results =>
          for r in results, i in [0:results.size] do
            vals := vals.insert (.opResult ⟨inner, i⟩) (.rv r)
        | .error m =>
          if isIntegerResult ctx inner then return fail m
          -- A float result: opaque (D22).
          for i in [0:inner.getNumResults! ctx] do
            vals := vals.insert (.opResult ⟨inner, i⟩) (opaqueOf inner ins.toList i)
      | none =>
        let r : Val := if ins.any (· == .undef) then .undef else opaqueOf inner ins.toList 0
        for i in [0:inner.getNumResults! ctx] do vals := vals.insert (.opResult ⟨inner, i⟩) r
    else
      -- Not interpreted (D22).
      let bufs := (memrefOperands ctx inner).filterMap fun m => lookup m >>= bufOfVal
      for b in bufs do
        if freed.contains b then return fail s!"'{iname}' used {ip.buffers[b]!.name} after it was deallocated"
      let readVals := ins.toList ++ bufs.toList.flatMap fun b =>
        (List.range ip.buffers[b]!.type.numel).map fun (q : Nat) => mem[(b, (q : Int))]?.getD .undef
      for b in writtenBuffers ctx inner (fun m => lookup m >>= bufOfVal) do
        for q in [0:ip.buffers[b]!.type.numel] do
          mem := mem.insert (b, (q : Int)) (opaqueOf inner readVals q)
      for i in [0:inner.getNumResults! ctx] do
        if !isMemRefType ((ValuePtr.opResult ⟨inner, i⟩).getType! ctx) then
          vals := vals.insert (.opResult ⟨inner, i⟩) (opaqueOf inner readVals (1000000 + i))
  let mut results := s.results
  for y in e.yields, i in [0:e.yields.size] do
    match vals[y]? <|> (c.env[y]? >>= s.resolve) with
    | some x => results := results.insert (v, i + 1) x
    | none => return fail "it yields a value that was not available"
  return { s with results, mem, freed }

def IProgram.finish (ctx : IRContext OpCode) (ip : IProgram) (v : Nat) (s : MState) : MState :=
  if s.fault.isSome then s else
  match ip.prog.events[v]? with
  | none => { s with fault := some s!"event {v} does not exist" }
  | some e =>
    match e.kind with
    | .execute | .syncOp => ip.finishExecute ctx v s
    | .dma | .dmaBlocking => ip.finishDma v s
    | _ => s

def IProgram.run (ctx : IRContext OpCode) (ip : IProgram) (order : List Nat) : MState :=
  order.foldl (fun s v => ip.finish ctx v s) ip.initState

/-! ### Footprints -/

/-- What each event reads and writes, from what is known before running: constants, host
arithmetic (loop induction variables included), the scalar arguments given. An access whose
elements are not known is the whole buffer (D23). Also returns problems inside single DMAs. -/
def IProgram.footprints (ctx : IRContext OpCode) (ip : IProgram) :
    Array (List Access) × Array EventIssue := Id.run do
  let whole (b : Nat) : List Int := (List.range ip.buffers[b]!.type.numel).map Int.ofNat
  let staticOf (h : HVal) : Option Val := match h with | .val v => some v | _ => none
  let bufOfH (h : HVal) : Option Nat := match h with
    | .val (.buf b) => some b
    | .result e i => ip.resultBufs[(e, i)]?
    | _ => none
  let mut fps := #[]
  let mut issues := #[]
  for e in ip.prog.events, v in [0:ip.prog.events.size] do
    let c := ip.ctxs[v]!
    let mut acc : List Access := []
    match e.kind with
    | .dma | .dmaBlocking =>
      let info := ip.dmas[v]!
      let some sb := c.env[info.src.memref]? >>= bufOfH | fps := fps.push acc; continue
      let some db := c.env[info.dst.memref]? >>= bufOfH | fps := fps.push acc; continue
      let st := ip.buffers[sb]!.type
      let dt := ip.buffers[db]!.type
      let entries (xs : Array (Int ⊕ ValuePtr)) : Option (Array Int) :=
        xs.mapM fun | .inl n => some n | .inr vp => c.env[vp]? >>= staticOf >>= Val.toInt?
      let known := do
        pure (← entries info.src.offsets, ← entries info.src.sizes, ← entries info.src.strides,
              ← entries info.dst.offsets, ← entries info.dst.sizes, ← entries info.dst.strides)
      match known with
      | none => acc := [⟨sb, .read, whole sb⟩, ⟨db, .write, whole db⟩]
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
          if let .error m := checkBounds st ip.buffers[sb]!.name reads then
            issues := issues.push ⟨v, s!"air.dma_memcpy_nd reads out of bounds: {m}"⟩
          if let .error m := checkBounds dt ip.buffers[db]!.name dpos then
            issues := issues.push ⟨v, s!"air.dma_memcpy_nd writes out of bounds: {m}"⟩
          if sb == db then
            let mut firstWrite : Std.HashMap Int Nat := {}
            for x in dpos, j in [0:dpos.length] do
              if !firstWrite.contains x then firstWrite := firstWrite.insert x j
            for x? in stream, i in [0:stream.length] do
              if let some x := x? then
                if let some j := firstWrite[x]? then
                  if i > j then
                    issues := issues.push ⟨v, s!"race inside air.dma_memcpy_nd on {ip.buffers[sb]!.name}: element {x} is read at step {i}, after it may already be written at step {j} (D21)"⟩
                    break
    | .execute | .syncOp =>
      let mut vals : Std.HashMap ValuePtr Val := {}
      let mut localBuf : Std.HashMap ValuePtr Nat := {}
      for inner in e.body do
        let iname := opName ctx inner
        let operands := inner.getOperands! ctx
        let bufOf (o : ValuePtr) : Option Nat := localBuf[o]? <|> (c.env[o]? >>= bufOfH)
        let valOf (o : ValuePtr) : Option Val := vals[o]? <|> (c.env[o]? >>= staticOf)
        let index (b : Nat) (idx : Array ValuePtr) : Option Int := do
          let t := ip.buffers[b]!.type
          if idx.size != t.shape.length then none
          let mut q : Int := 0
          for i in idx, stv in t.strides do
            let n ← valOf i >>= Val.toInt?
            q := q + n * stv
          return q
        if iname.startsWith "arith." then
          let ins := operands.toList.map fun o => (valOf o).getD .undef
          if let some rs := ins.mapM toRuntime? then
            if let .ok results := evalArith ctx inner rs.toArray then
              for r in results, i in [0:results.size] do
                vals := vals.insert (.opResult ⟨inner, i⟩) (.rv r)
        else if iname == "memref.alloc" then
          if let some b := c.allocBufs[inner]? then localBuf := localBuf.insert (.opResult ⟨inner, 0⟩) b
        else if viewOps.contains iname then
          if let some b := operands[0]? >>= bufOf then localBuf := localBuf.insert (.opResult ⟨inner, 0⟩) b
          -- `memref.reshape` reads its shape operand.
          if iname == "memref.reshape" then
            if let some b := operands[1]? >>= bufOf then acc := acc ++ [⟨b, .read, whole b⟩]
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
          for b in (memrefOperands ctx inner).filterMap bufOf do
            acc := acc ++ [⟨b, .read, whole b⟩]
          for b in writtenBuffers ctx inner bufOf do
            acc := acc ++ [⟨b, .write, whole b⟩]
    | _ => pure ()
    fps := fps.push acc
  return (fps, issues)

/-- The races, with a witness each: exactly `races` (proven exact by `raceFreeB_iff`). -/
def IProgram.raceReports (ip : IProgram) (fps : Array (List Access)) : List RaceReport :=
  let fp : Footprint := fun v => fps[v]?.getD []
  (races ip.prog.graph fp).filterMap fun (u, v) => do
    for a in fp u do
      for b in fp v do
        if a.conflictsB b then
          let bs : Std.HashSet Int := Std.HashSet.ofList b.elems
          if let some x := a.elems.find? bs.contains then
            let kind := match a.kind, b.kind with
              | .write, .read => "RAW" | .read, .write => "WAR" | _, _ => "WAW"
            return { first := u, second := v, kind, buffer := ip.buffers[a.buf]!.name, element := x }
    none

end

end Veir.Air
