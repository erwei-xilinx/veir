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

/-- Core instructions. Loop counters are per core. -/
inductive Instr where
  | acq (lock : Nat) (value : Int)
  | rel (lock : Nat) (value : Int)
  /-- An opaque computation: reads `reads` whole and overwrites `writes` whole (D22). -/
  | eff (op : Nat) (reads writes : Array Nat)
  | jmp (target : Nat)
  /-- Set a counter. -/
  | setc (counter : Nat) (value : Nat)
  /-- Decrement a counter; jump to `target` while it is still positive. -/
  | loop (counter : Nat) (target : Nat)
  | halt
deriving Inhabited, Repr

structure Core where
  name : String
  code : Array Instr
  counters : Nat
deriving Inhabited, Repr

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
  for unsupported in ["pad_before", "pad_after", "iteration", "dimensions", "packet"] do
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
      | "arith.constant" => pure ()
      | n => throw s!"BD chain: '{n}' is not supported in a BD block"
    let some (buf, ps) := bd | throw "BD chain: a block without aie.dma_bd"
    let term := ops.back!
    let next := if opName ctx term == "aie.next_bd" then
        (term.getSuccessors! ctx)[0]? >>= index.get?
      else none
    bds := bds.push { pre, buf, positions := ps, post, next }
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
    for o in ops do
      let n := opName ctx o
      if n == "aie.use_lock" then
        let u ← lockUse ctx o
        code := code.push (if u.acquire then .acq u.lock u.value else .rel u.lock u.value)
      else if n == "cf.br" then
        fixups := fixups.push (code.size, (o.getSuccessors! ctx)[0]!)
        code := code.push (.jmp 0)
      else if n == "aie.end" then
        code := code.push .halt
      else if n == "arith.constant" || n.startsWith "arith." || n == "affine.apply" then
        pure ()
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
        -- An opaque computation on its memref operands (D22).
        let st ← get
        let bufOf (m : ValuePtr) : Option Nat := st.bufOf[m]?
        let reads := (memrefOperands ctx o).filterMap bufOf
        let writes := writtenBuffers ctx o bufOf
        code := code.push (.eff o.id reads writes)
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
      | "aie.flow" | "aie.end" | "air.channel" | "aie.logical_tile" => pure ()
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
  return { buffers := st.buffers, hostArgs := st.hostArgs, locks := st.locks, chans := st.chans,
           routes, cores := st.cores, tasks := st.tasks, runtime := st.runtime }

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
deriving Inhabited, BEq, Hashable

structure CoreSt where
  pc : Nat := 0
  counters : Array Nat := #[]
deriving Inhabited, BEq, Hashable

structure St where
  locks : Array Int
  mem : Array (Array Val)
  chans : Array ChanSt
  cores : Array CoreSt
  rtPc : Nat
  tasksDone : Array Bool
deriving Inhabited

def St.key (s : St) : UInt64 :=
  let memH := s.mem.foldl (fun h a => a.foldl (fun h v => mixHash h (hash (showVal v))) h) 7
  mixHash (hash s.locks) (mixHash memH (mixHash (hash s.chans) (mixHash (hash s.cores)
    (mixHash (hash s.rtPc) (hash s.tasksDone)))))

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
      | .eff _ _ _ => "compute"
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
    let dsts := m.routes[c]!
    if dsts.isEmpty then continue
    let sbd := (m.bdsOf c cs)[b]!
    let mut n := sbd.positions.size - cs.idx
    let mut ok := true
    for d in dsts do
      let ds := s.chans[d]!
      match ds.bd with
      | some db =>
        if ds.phase != 1 then ok := false
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
      chans := chans.set! d { ds with idx := ds.idx + n }
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

structure Result where
  states : Nat
  complete : Bool
  /-- Host memory at the end of the runtime sequence, one entry per distinct outcome. -/
  outcomes : Array (Array (Array Val))
  /-- A reachable state where the runtime sequence has not finished and nothing can move, with
  the steps leading to it. -/
  deadlock : Option (Array String)

/-- Every interleaving, depth first, up to `limit` distinct states. -/
partial def Model.explore (m : Model) (limit : Nat := 200000) : Result := Id.run do
  let s0 := m.settle m.init
  let mut seen : Std.HashSet UInt64 := {}
  let mut stack : List (St × List String) := [(s0, [])]
  let mut outcomes : Array (Array (Array Val)) := #[]
  let mut outKeys : Std.HashSet UInt64 := {}
  let mut deadlock : Option (Array String) := none
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
    if s.rtPc ≥ m.runtime.size then
      let host := m.hostArgs.map (s.mem[·]!)
      let hk := host.foldl (fun h a => a.foldl (fun h v => mixHash h (hash (showVal v))) h) 11
      if !outKeys.contains hk then
        outKeys := outKeys.insert hk
        outcomes := outcomes.push host
      continue
    let next := m.steps s
    if next.isEmpty then
      if deadlock.isNone then deadlock := some trace.reverse.toArray
      continue
    for (l, s') in next do
      stack := (m.settle s', m.showLabel l :: trace) :: stack
  return { states := seen.size, complete, outcomes, deadlock }

end

end Veir.Air.Aie
