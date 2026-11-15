module

public import Veir.Air.Instance

namespace Veir.Air.Aie

@[expose] public section

/-! # C6 target model: AIE2P DMA buffer descriptors and locks

An executable model of an `aie.device` as `air-to-aie` and `airrt-to-npu` leave it. The hardware
decisions it encodes are T1-T5 in `AIE_SEMANTICS.md`:
- **T1:** locks are counting semaphores (`AcquireGreaterEqual v` waits for ≥ v and subtracts;
  `Release v` adds), without an upper bound.
- **T2:** a DMA channel walks its BD chain: each BD's acquires, its transfer, its releases, then
  `next_bd`; `aie.end` stops the chain.
- **T3:** streams have no buffering. A word moves only when the sending channel and every
  receiving channel of its flow take part.
- **T4:** cores run in program order and are persistent, so a `cf.br` back to a block loops
  forever.
- **T5:** `repeat_count = N` runs the whole task N + 1 times, re-acquiring its locks each time.

Everything not covered is refused, naming the op.

The model is explored exhaustively (`explore`): every interleaving of lock operations, transfers,
core instructions and runtime-sequence operations, up to a bound on states. A transfer moves as
many elements as its sender and all its receivers have left in their current BDs, in one step.
That is the same set of reachable lock and channel states as word by word. Memory interleavings
finer than a BD are not distinguished, as layer 2 does not distinguish them inside an event.
-/

/-! ## The model -/

structure LockUse where
  lock : Nat
  acquire : Bool
  value : Int
deriving Inhabited, Repr

/-- A buffer descriptor: its acquires, the elements it moves in order, its releases, and the BD
after it in the chain (`none`: the chain ends). -/
structure BD where
  pre : Array LockUse
  buf : Nat
  positions : Array Int
  post : Array LockUse
  next : Option Nat
  /-- The packet id a sending BD stamps (T6): each run of the BD is one packet. -/
  packet : Option Nat := none
deriving Inhabited, Repr

/-- A DMA channel. `mm2s` sends from memory to the stream, otherwise it receives. A tile channel
has a static BD chain from `aie.dma_start`; a shim channel runs the tasks the runtime pushes. -/
structure Chan where
  name : String
  mm2s : Bool
  bds : Array BD
  start : Option Nat
  repeatCount : Nat
deriving Inhabited, Repr

/-- An operand of a core statement. -/
inductive Arg where
  | reg (r : Nat)
  | lit (v : Val)
  /-- The induction variable of an enclosing counter loop: `lb + (trips - counter) * step`. -/
  | outerIv (counter : Nat) (lb step trips : Int) (width : Nat)
deriving Inhabited

/-- Core computation between lock operations, run atomically (as one AIR event runs): `arith`,
`memref.load`/`store`/`copy` on buffers, lock-free `scf.for`; anything else is opaque (D22). -/
inductive Stmt where
  | arith (f : Array RuntimeValue → Except String (Array RuntimeValue)) (op : Nat) (ins : Array Arg)
      (outs : Array Nat)
  | load (buf : Nat) (idx : Array Arg) (dst : Nat)
  | store (src : Arg) (buf : Nat) (idx : Array Arg)
  | copy (src dst : Nat)
  | forLoop (iv : Nat) (width : Nat) (lb ub step : Arg) (body : Array Stmt)
  | opaque (op : Nat) (ins : Array Arg) (reads writes : Array Nat) (outs : Array Nat)
deriving Inhabited

/-- Core instructions. Loop counters are per core. -/
inductive Instr where
  | acq (lock : Nat) (value : Int)
  | rel (lock : Nat) (value : Int)
  /-- An opaque computation: reads `reads` whole and overwrites `writes` whole (D22). -/
  | eff (op : Nat) (reads writes : Array Nat)
  /-- Lock-free computation, interpreted; `reads`/`writes` are its buffers, for the reduction. -/
  | exec (stmts : Array Stmt) (nregs : Nat) (reads writes : Array Nat)
  | jmp (target : Nat)
  /-- Set a counter. -/
  | setc (counter : Nat) (value : Nat)
  /-- Decrement a counter; jump to `target` while it is still positive. -/
  | loop (counter : Nat) (target : Nat)
  | halt
deriving Inhabited

structure Core where
  name : String
  code : Array Instr
  counters : Nat
deriving Inhabited

/-- A runtime-sequence task: a BD chain on a shim channel. -/
structure Task where
  chan : Nat
  bds : Array BD
  repeatCount : Nat
deriving Inhabited, Repr

inductive RtOp where
  | start (task : Nat)
  | await (task : Nat)
deriving Inhabited, Repr

structure Model where
  buffers : Array (String × MemRefType)
  /-- The runtime sequence's memref arguments, in order: host memory. -/
  hostArgs : Array Nat
  locks : Array (String × Int)
  chans : Array Chan
  /-- For each sending channel, the channels its flows reach (T3: all of them take each word). -/
  routes : Array (Array Nat)
  /-- Packet routes (T6-T10): (sender, packet id) to the receivers of that packet flow. -/
  pktRoutes : Std.HashMap (Nat × Nat) (Array Nat) := {}
  cores : Array Core
  tasks : Array Task
  runtime : Array RtOp
deriving Inhabited

/-! ## Extraction from `aie.device` -/

/-- The integer an unregistered op's property holds. -/
def propInt (ctx : IRContext OpCode) (op : OperationPtr) (name : String) : Option Int :=
  match findProp (unregProps ctx op) name with
  | some (.integerAttr i) => some i.value
  | _ => none

/-- Whether an op has an attribute (property or discardable) of that name. -/
def hasAnyAttr (ctx : IRContext OpCode) (op : OperationPtr) (name : String) : Bool :=
  (findProp (unregProps ctx op) name).isSome || hasAttrNamed ctx op name

/-- The blocks of an op's first region, in order. -/
def regionBlocks (ctx : IRContext OpCode) (op : OperationPtr) : Array BlockPtr := Id.run do
  let mut out := #[]
  let mut b := (op.getRegion! ctx 0).getFirstBlock! ctx
  for _ in [0:100000] do
    match b with
    | none => break
    | some blk =>
      out := out.push blk
      b := blk.getNextBlock! ctx
  return out

structure EState where
  buffers : Array (String × MemRefType) := #[]
  bufOf : Std.HashMap ValuePtr Nat := {}
  locks : Array (String × Int) := #[]
  lockOf : Std.HashMap ValuePtr Nat := {}
  /-- Tile ops to their coordinates. -/
  tiles : Std.HashMap ValuePtr (Int × Int) := {}
  chans : Array Chan := #[]
  /-- (column, row, mm2s, channel) to the channel. -/
  chanAt : Std.HashMap (Int × Int × Bool × Nat) Nat := {}
  /-- Shim DMA allocations: symbol to (column, row, mm2s, channel). -/
  shimAlloc : Std.HashMap String (Int × Int × Bool × Nat) := {}
  cores : Array Core := #[]
  tasks : Array Task := #[]
  taskOf : Std.HashMap ValuePtr Nat := {}
  runtime : Array RtOp := #[]
  hostArgs : Array Nat := #[]
  flows : Array ((Int × Int × Nat × Nat) × (Int × Int × Nat × Nat)) := #[]
  /-- Packet flows: source (column, row, bundle, channel), packet id, destinations. -/
  pktFlows : Array ((Int × Int × Nat × Nat) × Nat × Array (Int × Int × Nat × Nat)) := #[]
  /-- Induction variables of the counter loops enclosing the code being compiled. -/
  outerIvs : Std.HashMap ValuePtr (Nat × Int × Int × Int × Nat) := {}

abbrev EM := StateT EState (Except String)

def newBuffer (name : String) (t : TypeAttr) : EM Nat := do
  let ty ← match parseMemRefType (typeString t) with
    | .ok ty => pure ty
    | .error e => throw e
  modifyGet fun st => (st.buffers.size, { st with buffers := st.buffers.push (name, ty) })

/-- The constant an SSA value is, if an `arith.constant` defines it. -/
def constOf (ctx : IRContext OpCode) (v : ValuePtr) : Option Int :=
  match v with
  | .opResult ⟨d, _⟩ =>
    if opName ctx d == "arith.constant" then
      match d.getOpType! ctx with
      | .arith .constant =>
        match (d.getProperties! ctx (OpCode.arith .constant)) with
        | .int a => some a.value
        | .index a => some a.value.toInt
      | _ => none
    else none
  | _ => none

/-- `aie.use_lock`: action 1 is `Release`, 2 is `AcquireGreaterEqual` (`AIEAttrs.td`);
`Acquire` (0) is not used on AIE2P (T1). -/
def lockUse (ctx : IRContext OpCode) (op : OperationPtr) : EM LockUse := do
  let operands := op.getOperands! ctx
  let some l := (← get).lockOf[operands[0]!]? | throw "aie.use_lock: unknown lock"
  let v ← match operands[1]? >>= constOf ctx, propInt ctx op "value" with
    | some v, _ => pure v
    | none, some v => pure v
    | none, none => throw "aie.use_lock: the value is not a constant"
  match propInt ctx op "action" with
  | some 1 => return { lock := l, acquire := false, value := v }
  | some 2 => return { lock := l, acquire := true, value := v }
  | a => throw s!"aie.use_lock: action {a} is not supported (T1: only AcquireGreaterEqual and Release)"

/-- The elements an `aie.dma_bd` moves, in order: `offset + Σ iₖ·strideₖ`, sizes and strides
listed outermost first (`AIEOps.td`, `dma_bd`); without them, `len` contiguous elements. -/
def bdPositions (ctx : IRContext OpCode) (op : OperationPtr) (numel : Nat) : Except String (Array Int) := do
  let props := unregProps ctx op
  for unsupported in ["pad_before", "pad_after", "iteration", "dimensions", "out_of_order_id"] do
    if (findProp props unsupported).isSome then
      throw s!"aie.dma_bd: '{unsupported}' is not supported yet"
  let operands := op.getOperands! ctx
  if operands.size != 1 then throw "aie.dma_bd: runtime offsets or lengths are not supported"
  let offset := (propInt ctx op "static_offset").getD 0
  let len := ((propInt ctx op "static_len").map Int.toNat).getD numel
  match denseInts (findProp props "static_sizes"), denseInts (findProp props "static_strides") with
  | some sizes, some strides =>
    if sizes.size != strides.size then throw "aie.dma_bd: sizes and strides differ in length"
    let dims := (sizes.zip strides).toList.map fun (s, st) => ({ offset := 0, size := s.toNat, stride := st } : Dim)
    let ps := (positions dims).map (· + offset)
    if ps.length != len then throw s!"aie.dma_bd: the pattern has {ps.length} elements but len is {len}"
    return ps.toArray
  | none, none => return (List.range len).toArray.map fun (k : Nat) => offset + k
  | _, _ => throw "aie.dma_bd: sizes without strides"

/-- The `pkt_id` of an op's `packet = #aie.packet_info<pkt_type = t, pkt_id = i>`. -/
def packetId (ctx : IRContext OpCode) (op : OperationPtr) : Option Nat :=
  match findProp (unregProps ctx op) "packet" with
  | some a =>
    match ((Attribute.toString a).splitOn "pkt_id = ")[1]? with
    | some rest => (String.ofList (rest.toList.takeWhile Char.isDigit)).toNat?
    | none => none
  | none => none

/-- A BD chain from a block: each block holds acquires, one `aie.dma_bd`, releases, and ends in
`aie.next_bd` or `aie.end`. Returns the BDs and the index of `start`. -/
partial def bdChain (ctx : IRContext OpCode) (start : BlockPtr) (bufOfArg : ValuePtr → Option Nat) :
    EM (Array BD × Nat) := do
  let mut index : Std.HashMap BlockPtr Nat := {}
  let mut order : Array BlockPtr := #[]
  let mut work := [start]
  -- Number the blocks reachable through `next_bd`.
  while !work.isEmpty do
    let b := work.head!
    work := work.tail
    if index.contains b then continue
    let ops := blockOps ctx b
    let some term := ops.back? | throw "BD chain: empty block"
    if opName ctx term == "aie.end" then continue
    index := index.insert b order.size
    order := order.push b
    if opName ctx term == "aie.next_bd" then
      work := work ++ (term.getSuccessors! ctx).toList
    else throw s!"BD chain: a block ends in '{opName ctx term}'"
  let mut bds := #[]
  for b in order do
    let ops := blockOps ctx b
    let mut pre := #[]
    let mut post := #[]
    let mut bd : Option (Nat × Array Int) := none
    let mut pkt : Option Nat := none
    for op in ops.pop do
      match opName ctx op with
      | "aie.use_lock" =>
        let u ← lockUse ctx op
        if bd.isNone then pre := pre.push u else post := post.push u
      | "aie.dma_bd" =>
        if bd.isSome then throw "BD chain: two aie.dma_bd in one block"
        let m := (op.getOperands! ctx)[0]!
        let some buf := (← get).bufOf[m]? <|> bufOfArg m | throw "aie.dma_bd: unknown buffer"
        let numel := (← get).buffers[buf]!.2.numel
        let ps ← match bdPositions ctx op numel with
          | .ok ps => pure ps
          | .error e => throw e
        bd := some (buf, ps)
        pkt := packetId ctx op
      | "arith.constant" => pure ()
      | n => throw s!"BD chain: '{n}' is not supported in a BD block"
    let some (buf, ps) := bd | throw "BD chain: a block without aie.dma_bd"
    let term := ops.back!
    let next := if opName ctx term == "aie.next_bd" then
        (term.getSuccessors! ctx)[0]? >>= index.get?
      else none
    bds := bds.push { pre, buf, positions := ps, post, next, packet := pkt }
  return (bds, index[start]!)

/-- The channels an `aie.mem` / `aie.memtile_dma` / `aie.shim_dma` region starts. -/
partial def dmaRegion (ctx : IRContext OpCode) (op : OperationPtr) (tile : Int × Int) : EM Unit := do
  for b in regionBlocks ctx op do
    for o in blockOps ctx b do
      if opName ctx o != "aie.dma_start" then continue
      let mm2s := propInt ctx o "channel_dir" == some 1
      let some ch := propInt ctx o "channel" | throw "aie.dma_start: the channel is not an integer"
      let rep := ((propInt ctx o "repeat_count").getD 0).toNat
      let succ := o.getSuccessors! ctx
      let (bds, start) ← bdChain ctx succ[0]! (fun _ => none)
      let id := (← get).chans.size
      let name := s!"tile ({tile.1}, {tile.2}) {if mm2s then "MM2S" else "S2MM"} {ch}"
      modify fun st => { st with
        chans := st.chans.push { name, mm2s, bds, start := some start, repeatCount := rep },
        chanAt := st.chanAt.insert (tile.1, tile.2, mm2s, ch.toNat) id }

/-- Whether an op's regions contain lock operations or control flow. -/
partial def hasLocks (ctx : IRContext OpCode) (op : OperationPtr) : Bool := Id.run do
  for r in [0:op.getNumRegions! ctx] do
    let mut b := (op.getRegion! ctx r).getFirstBlock! ctx
    for _ in [0:100000] do
      match b with
      | none => break
      | some blk =>
        for o in blockOps ctx blk do
          let n := opName ctx o
          if n == "aie.use_lock" || n.startsWith "cf." || hasLocks ctx o then return true
        b := blk.getNextBlock! ctx
  return false

/-- The integer width of a value's type (`index` is 64). -/
def widthOf (ctx : IRContext OpCode) (v : ValuePtr) : Nat :=
  match typeString (v.getType! ctx) with
  | "index" => 64
  | t => match t.toList with
    | 'i' :: ds => (String.ofList ds).toNat?.getD 64
    | _ => 64

/-- Compile lock-free ops to statements. `regs` numbers the values defined so far in this run. -/
partial def compileStmts (ctx : IRContext OpCode) (ops : Array OperationPtr)
    (regs : Std.HashMap ValuePtr Nat) (nregs : Nat) :
    EM (Array Stmt × Std.HashMap ValuePtr Nat × Nat × Array Nat × Array Nat) := do
  let mut regs := regs
  let mut nregs := nregs
  let mut out : Array Stmt := #[]
  let mut reads : Array Nat := #[]
  let mut writes : Array Nat := #[]
  for o in ops do
    let n := opName ctx o
    let st ← get
    let argOf (v : ValuePtr) : EM Arg := do
      match constOf ctx v with
      | some c => return .lit (intVal ctx v c)
      | none =>
        match regs[v]? with
        | some r => return .reg r
        | none =>
          match st.outerIvs[v]? with
          | some (c, lb, step, trips, w) => return .outerIv c lb step trips w
          | none => throw s!"core: '{n}' uses a value computed before a lock operation (not supported)"
    let bufOf (v : ValuePtr) : EM Nat := do
      match st.bufOf[v]? with
      | some b => return b
      | none => throw s!"core: '{n}' accesses a memref that is not an aie.buffer"
    let newRegs (k : Nat) : Array Nat := (List.range k).toArray.map (nregs + ·)
    if n == "arith.constant" || n == "scf.yield" then continue
    else if n.startsWith "arith." then
      let ins ← (o.getOperands! ctx).mapM argOf
      let outs := newRegs (o.getNumResults! ctx)
      for i in [0:outs.size] do regs := regs.insert (.opResult ⟨o, i⟩) outs[i]!
      nregs := nregs + outs.size
      out := out.push (.arith (fun rs => evalArith ctx o rs) o.id ins outs)
    else if n == "memref.load" then
      let operands := o.getOperands! ctx
      let b ← bufOf operands[0]!
      let idx ← (operands.extract 1 operands.size).mapM argOf
      regs := regs.insert (.opResult ⟨o, 0⟩) nregs
      out := out.push (.load b idx nregs)
      nregs := nregs + 1
      reads := reads.push b
    else if n == "memref.store" then
      let operands := o.getOperands! ctx
      let v ← argOf operands[0]!
      let b ← bufOf operands[1]!
      let idx ← (operands.extract 2 operands.size).mapM argOf
      out := out.push (.store v b idx)
      writes := writes.push b
    else if n == "memref.copy" then
      let operands := o.getOperands! ctx
      let a ← bufOf operands[0]!
      let b ← bufOf operands[1]!
      out := out.push (.copy a b)
      reads := reads.push a
      writes := writes.push b
    else if n == "scf.for" then
      let operands := o.getOperands! ctx
      if operands.size > 3 then throw "core: scf.for with iter_args is not supported"
      let lb ← argOf operands[0]!
      let ub ← argOf operands[1]!
      let step ← argOf operands[2]!
      let some body := (o.getRegion! ctx 0).getFirstBlock! ctx | throw "core: empty scf.for"
      let iv := (body.getArguments! ctx)[0]!
      let ivReg := nregs
      regs := regs.insert iv ivReg
      nregs := nregs + 1
      let (stmts, regs', nregs', rs, ws) ← compileStmts ctx (blockOps ctx body) regs nregs
      regs := regs'
      nregs := nregs'
      reads := reads ++ rs
      writes := writes ++ ws
      out := out.push (.forLoop ivReg (widthOf ctx iv) lb ub step stmts)
    else
      -- Opaque (D22): reads its memref operands whole, overwrites those it writes.
      let ins ← ((o.getOperands! ctx).filter fun v => !isMemRefType (v.getType! ctx)).mapM argOf
      let bufOfOpt (m : ValuePtr) : Option Nat := st.bufOf[m]?
      let rs := (memrefOperands ctx o).filterMap bufOfOpt
      let ws := writtenBuffers ctx o bufOfOpt
      let outs := newRegs (o.getNumResults! ctx)
      for i in [0:outs.size] do regs := regs.insert (.opResult ⟨o, i⟩) outs[i]!
      nregs := nregs + outs.size
      out := out.push (.opaque o.id ins rs ws outs)
      reads := reads ++ rs
      writes := writes ++ ws
  return (out, regs, nregs, reads, writes)

/-- A core's region as instructions. Blocks are laid out in order; `cf.br` jumps; `scf.for` with
constant bounds becomes a counter loop; opaque ops read and write their memref operands (D22). -/
partial def coreCode (ctx : IRContext OpCode) (op : OperationPtr) : EM (Array Instr × Nat) := do
  let blocks := regionBlocks ctx op
  let mut code : Array Instr := #[]
  let mut start : Std.HashMap BlockPtr Nat := {}
  let mut fixups : Array (Nat × BlockPtr) := #[]
  let mut counters := 0
  -- `emit` lays out a block's ops; nested `scf.for` bodies are laid out in place.
  let rec emit (ops : Array OperationPtr) (code : Array Instr) (fixups : Array (Nat × BlockPtr))
      (counters : Nat) : EM (Array Instr × Array (Nat × BlockPtr) × Nat) := do
    let mut code := code
    let mut fixups := fixups
    let mut counters := counters
    -- Consecutive lock-free ops form one `exec`, so values flow between them.
    let mut pending : Array OperationPtr := #[]
    let isPlain (o : OperationPtr) : Bool :=
      let n := opName ctx o
      !(n == "aie.use_lock" || n == "cf.br" || n == "aie.end" || n == "scf.yield" ||
        n == "cf.cond_br" || n == "scf.if" || n == "scf.while" || (n == "scf.for" && hasLocks ctx o))
    for o in ops ++ #[] do
      let n := opName ctx o
      if isPlain o then
        pending := pending.push o
        continue
      if !pending.isEmpty then
        let (stmts, _, nregs, reads, writes) ← compileStmts ctx pending {} 0
        code := code.push (.exec stmts nregs reads writes)
        pending := #[]
      if n == "aie.use_lock" then
        let u ← lockUse ctx o
        code := code.push (if u.acquire then .acq u.lock u.value else .rel u.lock u.value)
      else if n == "cf.br" then
        fixups := fixups.push (code.size, (o.getSuccessors! ctx)[0]!)
        code := code.push (.jmp 0)
      else if n == "aie.end" then
        code := code.push .halt
      else if n == "scf.for" then
        let operands := o.getOperands! ctx
        let some lb := constOf ctx operands[0]! | throw "core: scf.for bounds must be constants"
        let some ub := constOf ctx operands[1]! | throw "core: scf.for bounds must be constants"
        let some st := constOf ctx operands[2]! | throw "core: scf.for bounds must be constants"
        if st ≤ 0 then throw "core: scf.for step must be positive"
        let trips := if ub > lb then ((ub - lb + st - 1) / st).toNat else 0
        if trips == 0 then continue
        let c := counters
        counters := counters + 1
        code := code.push (.setc c trips)
        let bodyStart := code.size
        let some body := (o.getRegion! ctx 0).getFirstBlock! ctx | throw "core: empty scf.for"
        let iv := (body.getArguments! ctx)[0]!
        modify fun es => { es with outerIvs := es.outerIvs.insert iv (c, lb, st, (trips : Int), widthOf ctx iv) }
        let (code', fix', ctr') ← emit (blockOps ctx body).pop code fixups counters
        code := code'
        fixups := fix'
        counters := ctr'
        code := code.push (.loop c bodyStart)
      else if n == "scf.yield" then
        pure ()
      else if n == "cf.cond_br" || n == "scf.if" || n == "scf.while" then
        throw s!"core: '{n}' is not supported yet"
      else
        pure ()
    if !pending.isEmpty then
      let (stmts, _, nregs, reads, writes) ← compileStmts ctx pending {} 0
      code := code.push (.exec stmts nregs reads writes)
    return (code, fixups, counters)
  for b in blocks do
    start := start.insert b code.size
    let (c', f', n') ← emit (blockOps ctx b) code fixups counters
    code := c'
    fixups := f'
    counters := n'
  for (at_, b) in fixups do
    let some t := start[b]? | throw "core: a branch to an unknown block"
    code := code.set! at_ (.jmp t)
  return (code, counters)

/-- The runtime sequence: tasks on shim channels, started and awaited in order. -/
partial def runtimeSeq (ctx : IRContext OpCode) (op : OperationPtr) : EM Unit := do
  let some block := (op.getRegion! ctx 0).getFirstBlock! ctx | return
  let mut argBuf : Std.HashMap ValuePtr Nat := {}
  for a in block.getArguments! ctx, i in [0:block.getNumArguments! ctx] do
    let t := a.getType! ctx
    if isMemRefType t then
      let b ← newBuffer s!"%arg{i}" t
      argBuf := argBuf.insert a b
      modify fun st => { st with hostArgs := st.hostArgs.push b }
  for o in blockOps ctx block do
    match opName ctx o with
    | "aiex.dma_configure_task_for" =>
      let some (.flatSymbolRefAttr sym) := findProp (unregProps ctx o) "alloc"
        | throw "aiex.dma_configure_task_for: missing alloc"
      let name := (if sym.value.startsWith "@" then (sym.value.drop 1).toString else sym.value)
      let some (c, r, mm2s, ch) := (← get).shimAlloc[name]?
        | throw s!"aiex.dma_configure_task_for: no aie.shim_dma_allocation @{name}"
      -- The shim channel, created on first use.
      let chan ← match (← get).chanAt[(c, r, mm2s, ch)]? with
        | some id => pure id
        | none =>
          let id := (← get).chans.size
          let nm := s!"shim ({c}, {r}) {if mm2s then "MM2S" else "S2MM"} {ch}"
          modify fun st => { st with
            chans := st.chans.push { name := nm, mm2s, bds := #[], start := none, repeatCount := 0 },
            chanAt := st.chanAt.insert (c, r, mm2s, ch) id }
          pure id
      let some first := (o.getRegion! ctx 0).getFirstBlock! ctx | throw "task: empty body"
      -- A task's body: BDs in one block, or a chain through next_bd.
      let ops := blockOps ctx first
      let (bds, _) ← if ops.any (fun x => opName ctx x == "aie.next_bd") then
          bdChain ctx first argBuf.get?
        else do
          -- One block of BDs ending in aie.end: chained in order.
          let mut acc := #[]
          for x in ops do
            if opName ctx x == "aie.dma_bd" then
              let m := (x.getOperands! ctx)[0]!
              let some buf := argBuf[m]? <|> (← get).bufOf[m]? | throw "task: unknown buffer"
              let numel := (← get).buffers[buf]!.2.numel
              let ps ← match bdPositions ctx x numel with
                | .ok ps => pure ps
                | .error e => throw e
              acc := acc.push ({ pre := #[], buf, positions := ps, post := #[], next := none } : BD)
            else if opName ctx x == "aie.end" || opName ctx x == "arith.constant" then pure ()
            else throw s!"task: '{opName ctx x}' is not supported"
          let n := acc.size
          pure (acc.mapIdx fun i bd => { bd with next := if i + 1 < n then some (i + 1) else none }, 0)
      let rep := ((propInt ctx o "repeat_count").getD 0).toNat
      -- A shim task on a packet flow stamps its header on every BD (T6).
      let bds := match packetId ctx o with
        | some p => bds.map fun bd => { bd with packet := some p }
        | none => bds
      let id := (← get).tasks.size
      modify fun st => { st with
        tasks := st.tasks.push { chan, bds, repeatCount := rep },
        taskOf := st.taskOf.insert (.opResult ⟨o, 0⟩) id }
    | "aiex.dma_start_task" =>
      let some t := (← get).taskOf[(o.getOperands! ctx)[0]!]? | throw "aiex.dma_start_task: unknown task"
      modify fun st => { st with runtime := st.runtime.push (.start t) }
    | "aiex.dma_await_task" =>
      let some t := (← get).taskOf[(o.getOperands! ctx)[0]!]? | throw "aiex.dma_await_task: unknown task"
      modify fun st => { st with runtime := st.runtime.push (.await t) }
    | "aiex.dma_free_task" | "arith.constant" => pure ()
    | n => throw s!"runtime sequence: '{n}' is not supported yet"

/-- Read an `aie.device`. -/
partial def extract (ctx : IRContext OpCode) (device : OperationPtr) : Except String Model := do
  let some block := (device.getRegion! ctx 0).getFirstBlock! ctx | throw "aie.device: empty"
  let ops := blockOps ctx block
  let go : EM Unit := do
    -- Declarations first, then programs, so that every reference resolves.
    for o in ops do
      match opName ctx o with
      | "aie.tile" =>
        let some c := propInt ctx o "col" | throw "aie.tile: no col"
        let some r := propInt ctx o "row" | throw "aie.tile: no row"
        modify fun st => { st with tiles := st.tiles.insert (.opResult ⟨o, 0⟩) (c, r) }
      | "aie.lock" =>
        let some (c, r) := (← get).tiles[(o.getOperands! ctx)[0]!]? | throw "aie.lock: unknown tile"
        let id := (propInt ctx o "lockID").getD (-1)
        let init := (propInt ctx o "init").getD 0
        modify fun st => { st with
          locks := st.locks.push (s!"lock ({c}, {r}) #{id}", init),
          lockOf := st.lockOf.insert (.opResult ⟨o, 0⟩) st.locks.size }
      | "aie.buffer" | "aie.external_buffer" =>
        let nm := match findProp (unregProps ctx o) "sym_name" with
          | some (.stringAttr s) => String.fromUTF8! s.value
          | _ => "buffer"
        let b ← newBuffer nm ((ValuePtr.opResult ⟨o, 0⟩).getType! ctx)
        modify fun st => { st with bufOf := st.bufOf.insert (.opResult ⟨o, 0⟩) b }
      | "aie.shim_dma_allocation" =>
        let some (c, r) := (← get).tiles[(o.getOperands! ctx)[0]!]? | throw "aie.shim_dma_allocation: unknown tile"
        let some (.stringAttr s) := findProp (unregProps ctx o) "sym_name" | throw "shim_dma_allocation: no name"
        let mm2s := propInt ctx o "channel_dir" == some 1
        let ch := ((propInt ctx o "channel_index").getD 0).toNat
        modify fun st => { st with shimAlloc := st.shimAlloc.insert (String.fromUTF8! s.value) (c, r, mm2s, ch) }
      | "aie.flow" =>
        let operands := o.getOperands! ctx
        let some (sc, sr) := (← get).tiles[operands[0]!]? | throw "aie.flow: unknown tile"
        let some (dc, dr) := (← get).tiles[operands[1]!]? | throw "aie.flow: unknown tile"
        let sb := ((propInt ctx o "source_bundle").getD 0).toNat
        let sch := ((propInt ctx o "source_channel").getD 0).toNat
        let db := ((propInt ctx o "dest_bundle").getD 0).toNat
        let dch := ((propInt ctx o "dest_channel").getD 0).toNat
        -- WireBundle 1 is DMA (AIEAttrs.td); cores and cascades on streams are not modelled yet.
        if sb != 1 || db != 1 then throw s!"aie.flow: only DMA-to-DMA flows are supported (bundles {sb} -> {db})"
        modify fun st => { st with flows := st.flows.push ((sc, sr, sb, sch), (dc, dr, db, dch)) }
      | "aie.packet_flow" =>
        let some id := propInt ctx o "ID" | throw "aie.packet_flow: no ID"
        if (match findProp (unregProps ctx o) "keep_pkt_header" with
            | some (.integerAttr i) => i.value != 0
            | some a => (Attribute.toString a).startsWith "true"
            | none => false) || hasAttrNamed ctx o "keep_pkt_header" then
          throw "aie.packet_flow: keep_pkt_header is not supported yet"
        let some body := (o.getRegion! ctx 0).getFirstBlock! ctx | throw "aie.packet_flow: empty"
        let mut src : Option (Int × Int × Nat × Nat) := none
        let mut dsts : Array (Int × Int × Nat × Nat) := #[]
        for e in blockOps ctx body do
          let en := opName ctx e
          if en != "aie.packet_source" && en != "aie.packet_dest" then continue
          let some (c, r) := (← get).tiles[(e.getOperands! ctx)[0]!]? | throw s!"{en}: unknown tile"
          let b := ((propInt ctx e "bundle").getD 0).toNat
          let ch := ((propInt ctx e "channel").getD 0).toNat
          if b != 1 then throw s!"{en}: only DMA endpoints are supported (bundle {b})"
          if en == "aie.packet_source" then src := some (c, r, b, ch) else dsts := dsts.push (c, r, b, ch)
        let some sk := src | throw "aie.packet_flow: no source"
        modify fun st => { st with pktFlows := st.pktFlows.push (sk, id.toNat, dsts) }
      | _ => pure ()
    for o in ops do
      match opName ctx o with
      | "aie.mem" | "aie.memtile_dma" | "aie.shim_dma" =>
        let some t := (← get).tiles[(o.getOperands! ctx)[0]!]? | throw s!"{opName ctx o}: unknown tile"
        dmaRegion ctx o t
      | "aie.core" =>
        let some (c, r) := (← get).tiles[(o.getOperands! ctx)[0]!]? | throw "aie.core: unknown tile"
        let (code, counters) ← coreCode ctx o
        modify fun st => { st with cores := st.cores.push { name := s!"core ({c}, {r})", code, counters } }
      | "aie.runtime_sequence" => runtimeSeq ctx o
      | "aie.tile" | "aie.lock" | "aie.buffer" | "aie.external_buffer" | "aie.shim_dma_allocation"
      | "aie.flow" | "aie.packet_flow" | "aie.end" | "air.channel" | "aie.logical_tile" => pure ()
      | n => throw s!"aie.device: '{n}' is not supported yet"
  let ((), st) ← go.run {}
  -- Routes: each sending channel to every channel its flows reach.
  let mut routes : Array (Array Nat) := Array.replicate st.chans.size #[]
  for ((sc, sr, _, sch), (dc, dr, _, dch)) in st.flows do
    let some s := st.chanAt[(sc, sr, true, sch)]?
      | throw s!"aie.flow: no MM2S channel {sch} on tile ({sc}, {sr})"
    let some d := st.chanAt[(dc, dr, false, dch)]?
      | throw s!"aie.flow: no S2MM channel {dch} on tile ({dc}, {dr})"
    routes := routes.modify s (·.push d)
  let mut pktRoutes : Std.HashMap (Nat × Nat) (Array Nat) := {}
  for ((sc, sr, _, sch), id, dsts) in st.pktFlows do
    let some s := st.chanAt[(sc, sr, true, sch)]?
      | throw s!"aie.packet_flow: no MM2S channel {sch} on tile ({sc}, {sr})"
    let mut ds := #[]
    for (dc, dr, _, dch) in dsts do
      let some d := st.chanAt[(dc, dr, false, dch)]?
        | throw s!"aie.packet_flow: no S2MM channel {dch} on tile ({dc}, {dr})"
      ds := ds.push d
    pktRoutes := pktRoutes.insert (s, id) ds
  return { buffers := st.buffers, hostArgs := st.hostArgs, locks := st.locks, chans := st.chans,
           routes, pktRoutes, cores := st.cores, tasks := st.tasks, runtime := st.runtime }

/-! ## Semantics -/

/-- Where a channel is: the BD and its phase (0: acquires, 1: transfer, 2: releases), how far
into that phase, and how many more runs of the chain remain (T5). -/
structure ChanSt where
  bd : Option Nat := none
  phase : Nat := 0
  idx : Nat := 0
  runsLeft : Nat := 0
  /-- Shim channels: the task running and those queued. -/
  task : Option Nat := none
  queue : List Nat := []
  /-- A receiver of packets: the sender whose packet it is taking (T8: packets do not interleave). -/
  pktFrom : Option Nat := none
deriving Inhabited, DecidableEq, Hashable

structure CoreSt where
  pc : Nat := 0
  counters : Array Nat := #[]
deriving Inhabited, DecidableEq, Hashable

structure St where
  locks : Array Int
  mem : Array (Array Val)
  chans : Array ChanSt
  cores : Array CoreSt
  rtPc : Nat
  tasksDone : Array Bool
  /-- A core computation went wrong (out of bounds, an arith failure): reported, not explored. -/
  fault : Option String := none
deriving Inhabited, DecidableEq

def St.key (s : St) : UInt64 :=
  let memH := s.mem.foldl (fun h a => a.foldl (fun h v => mixHash h (hash (showVal v))) h) 7
  mixHash (hash s.locks) (mixHash memH (mixHash (hash s.chans) (mixHash (hash s.cores)
    (mixHash (hash s.rtPc) (mixHash (hash s.tasksDone) (hash s.fault))))))

def Model.init (m : Model) : St := Id.run do
  let mut mem := m.buffers.map fun (_, t) => Array.replicate t.numel Val.undef
  for b in m.hostArgs, j in [0:m.hostArgs.size] do
    let t := m.buffers[b]!.2
    mem := mem.set! b <| (List.range t.numel).toArray.map fun q =>
      if t.bitwidth > 0 then .rv (.int t.bitwidth (.val (BitVec.ofInt t.bitwidth (1000 * j + q))))
      else .opaque 1000000 (1000 * j + q).toUInt64
  let chans := m.chans.map fun c => match c.start with
    | some s => { bd := some s, runsLeft := c.repeatCount }
    | none => {}
  return { locks := m.locks.map (·.2), mem, chans,
           cores := m.cores.map fun c => { counters := Array.replicate c.counters 0 },
           rtPc := 0, tasksDone := Array.replicate m.tasks.size false }

/-- The BDs a channel is walking: its static chain, or its current task's. -/
def Model.bdsOf (m : Model) (c : Nat) (cs : ChanSt) : Array BD :=
  match cs.task with
  | some t => m.tasks[t]!.bds
  | none => m.chans[c]!.bds

/-- A step, for traces. -/
inductive Label where
  | chanLock (c : Nat) (u : LockUse)
  | transfer (src : Nat) (dsts : Array Nat) (n : Nat)
  | taskBegin (c : Nat) (t : Nat)
  | core (k : Nat) (i : Instr)
  | rt (op : RtOp)
deriving Inhabited

def Model.showLabel (m : Model) : Label → String
  | .chanLock c u => s!"{m.chans[c]!.name}: {if u.acquire then "acquire" else "release"} {m.locks[u.lock]!.1} {u.value}"
  | .transfer s ds n => s!"{m.chans[s]!.name} -> {", ".intercalate (ds.toList.map (m.chans[·]!.name))}: {n} element(s)"
  | .taskBegin c t => s!"{m.chans[c]!.name}: begins task {t}"
  | .core k i => s!"{m.cores[k]!.name}: {match i with
      | .acq l v => s!"acquire {m.locks[l]!.1} {v}"
      | .rel l v => s!"release {m.locks[l]!.1} {v}"
      | .eff _ _ _ | .exec _ _ _ _ => "compute"
      | _ => "control"}"
  | .rt (.start t) => s!"runtime: start task {t}"
  | .rt (.await t) => s!"runtime: await task {t}"

/-- After a channel finishes a BD's releases: the next BD, another run of the chain, the next
queued task, or idle. Returns the new channel state and the task it completed, if any. -/
def Model.advance (m : Model) (c : Nat) (cs : ChanSt) : ChanSt × Option Nat :=
  let bds := m.bdsOf c cs
  match cs.bd >>= fun b => bds[b]? >>= (·.next) with
  | some n => ({ cs with bd := some n, phase := 0, idx := 0 }, none)
  | none =>
    if cs.runsLeft > 0 then
      ({ cs with bd := some 0, phase := 0, idx := 0, runsLeft := cs.runsLeft - 1 }, none)
    else
      match cs.task with
      | some t => ({ cs with bd := none, task := none, phase := 0, idx := 0 }, some t)
      | none => ({ cs with bd := none, phase := 0, idx := 0 }, none)

def argVal (regs : Array Val) (counters : Array Nat) : Arg → Val
  | .reg r => regs[r]!
  | .lit v => v
  | .outerIv c lb st trips w => .rv (.int w (.val (BitVec.ofInt w (lb + (trips - (counters[c]! : Int)) * st))))

/-- The element an index list names in a buffer (row-major), checked against its shape. -/
def linearIndex (t : MemRefType) (idx : Array Val) : Except String Nat := do
  if idx.size != t.shape.length then throw "wrong number of indices"
  let mut q : Int := 0
  for i in idx, d in t.shape, stv in t.strides do
    let some n := i.toInt? | throw "an index is not a known integer"
    if n < 0 || n ≥ d then throw s!"index {n} is outside a dimension of size {d}"
    q := q + n * stv
  return q.toNat

/-- Run statements on memory and registers. -/
partial def runStmts (types : Array MemRefType) (counters : Array Nat) (stmts : Array Stmt)
    (mem : Array (Array Val)) (regs : Array Val) : Except String (Array (Array Val) × Array Val) := do
  let mut mem := mem
  let mut regs := regs
  for st in stmts do
    match st with
    | .arith f op ins outs =>
      let vs := ins.map (argVal regs counters)
      match vs.toList.mapM toRuntime? with
      | some rs =>
        let res ← f rs.toArray
        for r in res, o in outs do regs := regs.set! o (.rv r)
      | none =>
        let v : Val := if vs.any (· == .undef) then .undef
          else .opaque op (hash (", ".intercalate (vs.toList.map showVal)))
        for o in outs do regs := regs.set! o v
    | .load b idx dst =>
      let q ← linearIndex types[b]! (idx.map (argVal regs counters))
      regs := regs.set! dst ((mem[b]!)[q]!)
    | .store src b idx =>
      let q ← linearIndex types[b]! (idx.map (argVal regs counters))
      let v := argVal regs counters src
      mem := mem.modify b (·.set! q v)
    | .copy a b =>
      if (mem[a]!).size != (mem[b]!).size then throw "memref.copy between buffers of different sizes"
      mem := mem.set! b mem[a]!
    | .forLoop iv w lb ub step body =>
      let some l := (argVal regs counters lb).toInt? | throw "scf.for: unknown lower bound"
      let some u := (argVal regs counters ub).toInt? | throw "scf.for: unknown upper bound"
      let some sp := (argVal regs counters step).toInt? | throw "scf.for: unknown step"
      if sp ≤ 0 then throw "scf.for: non-positive step"
      let trips := if u > l then ((u - l + sp - 1) / sp).toNat else 0
      for k in [0:trips] do
        regs := regs.set! iv (.rv (.int w (.val (BitVec.ofInt w (l + k * sp)))))
        let (m', r') ← runStmts types counters body mem regs
        mem := m'
        regs := r'
    | .opaque op ins reads writes outs =>
      let vs := (ins.map (argVal regs counters)).toList ++ reads.toList.flatMap fun b => (mem[b]!).toList
      let h := hash (", ".intercalate (vs.map showVal))
      for b in writes do
        mem := mem.set! b ((List.range (mem[b]!).size).toArray.map fun q => Val.opaque op (mixHash h (hash s!"{b}:{q}")))
      for o in outs, i in [0:outs.size] do regs := regs.set! o (.opaque op (mixHash h (hash i)))
  return (mem, regs)

/-- Every step enabled in a state, with the state it leads to. -/
def Model.steps (m : Model) (s : St) : Array (Label × St) := Id.run do
  let mut out := #[]
  -- Channels: lock operations, and shim channels beginning a queued task.
  for cs in s.chans, c in [0:s.chans.size] do
    match cs.bd with
    | none =>
      if let t :: rest := cs.queue then
        let cs' := { cs with task := some t, queue := rest, bd := some 0, phase := 0, idx := 0,
                             runsLeft := m.tasks[t]!.repeatCount }
        out := out.push (.taskBegin c t, { s with chans := s.chans.set! c cs' })
    | some b =>
      let bd := (m.bdsOf c cs)[b]!
      if cs.phase == 0 then
        match bd.pre[cs.idx]? with
        | some u =>
          if !u.acquire || s.locks[u.lock]! ≥ u.value then
            let v := if u.acquire then s.locks[u.lock]! - u.value else s.locks[u.lock]! + u.value
            out := out.push (.chanLock c u, { s with locks := s.locks.set! u.lock v,
                                                       chans := s.chans.set! c { cs with idx := cs.idx + 1 } })
        | none => pure ()  -- acquires done: the transfer phase starts below
      else if cs.phase == 2 then
        match bd.post[cs.idx]? with
        | some u =>
          if !u.acquire || s.locks[u.lock]! ≥ u.value then
            let v := if u.acquire then s.locks[u.lock]! - u.value else s.locks[u.lock]! + u.value
            let s' := { s with locks := s.locks.set! u.lock v }
            let cs' := { cs with idx := cs.idx + 1 }
            if cs'.idx ≥ bd.post.size then
              let (cs'', done) := m.advance c cs'
              let td := match done with | some t => s'.tasksDone.set! t true | none => s'.tasksDone
              out := out.push (.chanLock c u, { s' with chans := s'.chans.set! c cs'', tasksDone := td })
            else
              out := out.push (.chanLock c u, { s' with chans := s'.chans.set! c cs' })
        | none => pure ()
  -- Normalise: a channel whose acquires are done enters its transfer; one whose releases are
  -- done (or that has none) advances. These moves have no effect of their own.
  -- Transfers: a sender in its transfer phase and all its receivers in theirs (T3).
  for c in [0:m.chans.size] do
    if !m.chans[c]!.mm2s then continue
    let cs := s.chans[c]!
    let some b := cs.bd | continue
    if cs.phase != 1 then continue
    let sbd := (m.bdsOf c cs)[b]!
    -- A packet goes to its flow's receivers, each taking it whole (T6, T8); circuit data to
    -- the circuit flow's (T3).
    let dsts := match sbd.packet with
      | some p => (m.pktRoutes[(c, p)]?).getD #[]
      | none => m.routes[c]!
    if dsts.isEmpty then continue
    let mut n := sbd.positions.size - cs.idx
    let mut ok := true
    for d in dsts do
      let ds := s.chans[d]!
      match ds.bd with
      | some db =>
        if ds.phase != 1 then ok := false
        else if sbd.packet.isSome && !(ds.pktFrom == none || ds.pktFrom == some c) then ok := false
        else n := min n ((m.bdsOf d ds)[db]!.positions.size - ds.idx)
      | none => ok := false
    if !ok || n == 0 then continue
    let mut mem := s.mem
    let mut chans := s.chans
    let words := (List.range n).map fun (k : Nat) => (s.mem[sbd.buf]!)[(sbd.positions[cs.idx + k]!).toNat]?.getD .undef
    for d in dsts do
      let ds := chans[d]!
      let dbd := (m.bdsOf d ds)[ds.bd.get!]!
      for w in words, k in [0:n] do
        let q := (dbd.positions[ds.idx + k]!).toNat
        mem := mem.modify dbd.buf (·.set! q w)
      -- A packet holds its receivers from its first word until the sender's BD ends (T6, T9).
      let grant := if sbd.packet.isNone then ds.pktFrom
        else if cs.idx + n ≥ sbd.positions.size then none else some c
      chans := chans.set! d { ds with idx := ds.idx + n, pktFrom := grant }
    chans := chans.set! c { cs with idx := cs.idx + n }
    out := out.push (.transfer c dsts n, { s with mem, chans })
  -- Cores.
  for k in [0:m.cores.size] do
    let cst := s.cores[k]!
    let some i := m.cores[k]!.code[cst.pc]? | continue
    match i with
    | .acq l v =>
      if s.locks[l]! ≥ v then
        out := out.push (.core k i, { s with locks := s.locks.set! l (s.locks[l]! - v),
                                             cores := s.cores.set! k { cst with pc := cst.pc + 1 } })
    | .rel l v =>
      out := out.push (.core k i, { s with locks := s.locks.set! l (s.locks[l]! + v),
                                           cores := s.cores.set! k { cst with pc := cst.pc + 1 } })
    | .eff op reads writes =>
      let ins := reads.toList.flatMap fun b => (s.mem[b]!).toList
      let mem := writes.foldl (fun mem b => mem.set! b ((List.range (mem[b]!).size).toArray.map fun q =>
        Val.opaque op (hash (", ".intercalate (ins.map showVal) ++ s!"#{b}:{q}")))) s.mem
      out := out.push (.core k i, { s with mem, cores := s.cores.set! k { cst with pc := cst.pc + 1 } })
    | .exec stmts nregs _ _ =>
      let types := m.buffers.map (·.2)
      let cores := s.cores.set! k { cst with pc := cst.pc + 1 }
      match runStmts types cst.counters stmts s.mem (Array.replicate nregs .undef) with
      | .ok (mem, _) => out := out.push (.core k i, { s with mem, cores })
      | .error e => out := out.push (.core k i, { s with cores, fault := some s!"{m.cores[k]!.name}: {e}" })
    | _ => pure ()
  -- Runtime sequence.
  if let some op := m.runtime[s.rtPc]? then
    match op with
    | .start t =>
      let c := m.tasks[t]!.chan
      let cs := s.chans[c]!
      out := out.push (.rt op, { s with rtPc := s.rtPc + 1,
                                         chans := s.chans.set! c { cs with queue := cs.queue ++ [t] } })
    | .await t =>
      if s.tasksDone[t]! then out := out.push (.rt op, { s with rtPc := s.rtPc + 1 })
  return out

/-- Moves with no effect, taken eagerly: a channel whose acquires are done enters its transfer;
one whose transfer is done enters its releases; one whose releases are done advances; core
control flow (`jmp`, `setc`, `loop`). -/
partial def Model.settle (m : Model) (s : St) : St := Id.run do
  let mut s := s
  for _ in [0:100000] do
    let mut changed := false
    for cs in s.chans, c in [0:s.chans.size] do
      let some b := cs.bd | continue
      let bd := (m.bdsOf c cs)[b]!
      if cs.phase == 0 && cs.idx ≥ bd.pre.size then
        s := { s with chans := s.chans.set! c { cs with phase := 1, idx := 0 } }
        changed := true
      else if cs.phase == 1 && cs.idx ≥ bd.positions.size then
        s := { s with chans := s.chans.set! c { cs with phase := 2, idx := 0 } }
        changed := true
      else if cs.phase == 2 && cs.idx ≥ bd.post.size then
        let (cs', done) := m.advance c cs
        let td := match done with | some t => s.tasksDone.set! t true | none => s.tasksDone
        s := { s with chans := s.chans.set! c cs', tasksDone := td }
        changed := true
    for k in [0:m.cores.size] do
      let cst := s.cores[k]!
      match m.cores[k]!.code[cst.pc]? with
      | some (.jmp t) =>
        if t != cst.pc then
          s := { s with cores := s.cores.set! k { cst with pc := t } }
          changed := true
      | some (.setc c n) =>
        s := { s with cores := s.cores.set! k { cst with pc := cst.pc + 1, counters := cst.counters.set! c n } }
        changed := true
      | some (.loop c t) =>
        let v := cst.counters[c]! - 1
        s := { s with cores := s.cores.set! k { cst with pc := if v > 0 then t else cst.pc + 1,
                                                          counters := cst.counters.set! c v } }
        changed := true
      | _ => pure ()
    if !changed then break
  return s

/-! ## Partial-order reduction (stubborn sets)

Each DMA channel, each core and the runtime sequence is an *agent* with one next action in each
state, enabled or not; a transfer is a joint action of its sender and receivers. From one agent
with an enabled action, `stubborn` closes a set of agents:
- for an enabled action, every agent that could ever conflict with it: another acquirer of one of
  its locks, a reader or writer of a buffer it writes, a writer of a buffer it reads, the parties
  of a transfer, and, for anything touching host memory or a shim channel, the runtime and all
  such agents. This is judged on each agent's whole static footprint, conservatively;
- for a disabled action, every agent that could enable it: the releasers of the lock it waits
  for, the other parties of its transfer, the runtime for a shim channel with nothing queued, the
  channel of the task an await waits for.

Only the steps of agents in the set are expanded. Releases never disable anything, and steps
outside the set commute with those inside, so every terminal state (a deadlock, or the end of the
runtime sequence, after which nothing is explored) stays reachable (Valmari's stubborn sets). This
argument is not formalised; `--no-por` explores without the reduction, and the tests compare the
two. -/

/-- What an agent may ever touch. -/
structure Foot where
  acq : Std.HashSet Nat := {}
  rel : Std.HashSet Nat := {}
  rd : Std.HashSet Nat := {}
  wr : Std.HashSet Nat := {}
  /-- Touches host memory or is a shim channel: conflicts with the runtime sequence. -/
  host : Bool := false
deriving Inhabited

/-- Agents: channels `0 … C-1`, cores `C … C+K-1`, the runtime `C+K`. -/
def Model.runtimeAgent (m : Model) : Nat := m.chans.size + m.cores.size

def Model.feet (m : Model) : Array Foot := Id.run do
  let isHost (b : Nat) := m.hostArgs.contains b
  let mut out := #[]
  for c in m.chans, ci in [0:m.chans.size] do
    let mut f : Foot := { host := c.start.isNone }
    let bds := c.bds ++ (m.tasks.filter (·.chan == ci)).flatMap (·.bds)
    for bd in bds do
      for u in bd.pre ++ bd.post do
        f := if u.acquire then { f with acq := f.acq.insert u.lock } else { f with rel := f.rel.insert u.lock }
      f := if c.mm2s then { f with rd := f.rd.insert bd.buf } else { f with wr := f.wr.insert bd.buf }
      if isHost bd.buf then f := { f with host := true }
    out := out.push f
  for k in m.cores do
    let mut f : Foot := {}
    for i in k.code do
      match i with
      | .acq l _ => f := { f with acq := f.acq.insert l }
      | .rel l _ => f := { f with rel := f.rel.insert l }
      | .eff _ rs ws | .exec _ _ rs ws =>
        f := { f with rd := rs.foldl (·.insert ·) f.rd, wr := ws.foldl (·.insert ·) f.wr }
        if (rs ++ ws).any isHost then f := { f with host := true }
      | _ => pure ()
    out := out.push f
  out := out.push { host := true }
  return out

def Model.ownersOf (m : Model) : Label → List Nat
  | .chanLock c _ => [c]
  | .transfer src dsts _ => src :: dsts.toList
  | .taskBegin c _ => [c]
  | .core k _ => [m.chans.size + k]
  | .rt _ => [m.runtimeAgent]

/-- An agent's next action: the resources it touches, whether it is enabled, and who could
enable it. `none`: the agent never acts again. -/
structure Act where
  enabled : Bool
  acq : List Nat := []
  rd : List Nat := []
  wr : List Nat := []
  host : Bool := false
  /-- Agents that must take part (a transfer's parties) or could enable it. -/
  others : List Nat := []

/-- Every channel that may send to `c`, through a circuit or a packet flow. -/
def Model.senders (m : Model) (c : Nat) : List Nat :=
  (List.range m.chans.size).filter fun s =>
    m.routes[s]!.contains c || m.pktRoutes.toList.any fun ((s', _), ds) => s' == s && ds.contains c

def Model.nextAct (m : Model) (feet : Array Foot) (s : St) (enabled : Std.HashSet Nat) (a : Nat) : Option Act :=
  let releasers (l : Nat) := (List.range feet.size).filter fun b => b != a && feet[b]!.rel.contains l
  let on := enabled.contains a
  if a < m.chans.size then
    let c := a
    let cs := s.chans[c]!
    match cs.bd with
    | none =>
      -- A shim channel waits for the runtime to queue a task; a tile channel's chain is over.
      if m.chans[c]!.start.isNone then some { enabled := on, host := true, others := [m.runtimeAgent] }
      else none
    | some b =>
      let bd := (m.bdsOf c cs)[b]!
      let lockAct (u : LockUse) : Act :=
        if u.acquire then { enabled := on, acq := [u.lock], host := feet[c]!.host, others := releasers u.lock }
        else { enabled := on, host := feet[c]!.host }
      if cs.phase == 0 then (bd.pre[cs.idx]?).map lockAct
      else if cs.phase == 2 then (bd.post[cs.idx]?).map lockAct
      else
        -- A sender's receivers (for a packet: its flow's), and every other sender that may compete
        -- for them (T8); a receiver's possible senders.
        let rcv := match bd.packet with
          | some p => ((m.pktRoutes[(c, p)]?).getD #[]).toList
          | none => m.routes[c]!.toList
        let parties := if m.chans[c]!.mm2s then rcv ++ rcv.flatMap m.senders else m.senders c
        if m.chans[c]!.mm2s then some { enabled := on, rd := [bd.buf], host := feet[c]!.host, others := parties }
        else some { enabled := on, wr := [bd.buf], host := feet[c]!.host, others := parties }
  else if a < m.runtimeAgent then
    let k := a - m.chans.size
    match m.cores[k]!.code[s.cores[k]!.pc]? with
    | some (.acq l _) => some { enabled := on, acq := [l], others := releasers l }
    | some (.rel _ _) => some { enabled := on }
    | some (.eff _ rs ws) | some (.exec _ _ rs ws) => some { enabled := on, rd := rs.toList, wr := ws.toList, host := feet[a]!.host }
    | _ => none
  else
    match m.runtime[s.rtPc]? with
    | some (.start _) => some { enabled := on, host := true }
    | some (.await t) => some { enabled := on, host := true, others := [m.tasks[t]!.chan] }
    | none => none

/-- Whether an action could ever conflict with what agent `b` may do. -/
def conflicts (act : Act) (f : Foot) : Bool :=
  act.acq.any f.acq.contains || act.wr.any (fun x => f.rd.contains x || f.wr.contains x) ||
    act.rd.any f.wr.contains || (act.host && f.host)

/-- The steps of a stubborn set: the smallest closure from any agent with an enabled action. -/
def Model.stubborn (m : Model) (feet : Array Foot) (s : St) (next : Array (Label × St)) : Array (Label × St) := Id.run do
  let enabled : Std.HashSet Nat := next.foldl (fun acc (l, _) => (m.ownersOf l).foldl (·.insert ·) acc) {}
  let mut best : Option (Std.HashSet Nat) := none
  for a0 in enabled.toList do
    let mut inSet : Std.HashSet Nat := ({} : Std.HashSet Nat).insert a0
    let mut work := [a0]
    for _ in [0:feet.size * feet.size + 1] do
      match work with
      | [] => break
      | a :: rest =>
        work := rest
        let some act := m.nextAct feet s enabled a | continue
        let adds := if act.enabled then
            act.others ++ ((List.range feet.size).filter fun b => b != a && conflicts act feet[b]!)
          else act.others
        for b in adds do
          if !inSet.contains b then
            inSet := inSet.insert b
            work := b :: work
    if best.all (inSet.size < ·.size) then best := some inSet
  match best with
  | none => return next
  | some set => return next.filter fun (l, _) => (m.ownersOf l).all set.contains

structure Result where
  states : Nat
  complete : Bool
  /-- Host memory at the end of the runtime sequence, one entry per distinct outcome. -/
  outcomes : Array (Array (Array Val))
  /-- A reachable state where the runtime sequence has not finished and nothing can move, with
  the steps leading to it. -/
  deadlock : Option (Array String)
  /-- A core computation that went wrong, with the steps leading to it. -/
  fault : Option (String × Array String) := none

/-- Every interleaving, depth first, up to `limit` distinct states. -/
partial def Model.explore (m : Model) (limit : Nat := 200000) (por : Bool := true) : Result := Id.run do
  let feet := m.feet
  let s0 := m.settle m.init
  let mut seen : Std.HashSet UInt64 := {}
  let mut stack : List (St × List String) := [(s0, [])]
  let mut outcomes : Array (Array (Array Val)) := #[]
  let mut outKeys : Std.HashSet UInt64 := {}
  let mut deadlock : Option (Array String) := none
  let mut fault : Option (String × Array String) := none
  let mut complete := true
  while !stack.isEmpty do
    let (s, trace) := stack.head!
    stack := stack.tail
    let k := s.key
    if seen.contains k then continue
    if seen.size ≥ limit then
      complete := false
      break
    seen := seen.insert k
    if let some f := s.fault then
      if fault.isNone then fault := some (f, trace.reverse.toArray)
      continue
    if s.rtPc ≥ m.runtime.size then
      let host := m.hostArgs.map (s.mem[·]!)
      let hk := host.foldl (fun h a => a.foldl (fun h v => mixHash h (hash (showVal v))) h) 11
      if !outKeys.contains hk then
        outKeys := outKeys.insert hk
        outcomes := outcomes.push host
      continue
    let all := m.steps s
    let next := if por then m.stubborn feet s all else all
    if next.isEmpty then
      if deadlock.isNone then deadlock := some trace.reverse.toArray
      continue
    for (l, s') in next do
      stack := (m.settle s', m.showLabel l :: trace) :: stack
  return { states := seen.size, complete, outcomes, deadlock, fault }

end

end Veir.Air.Aie
