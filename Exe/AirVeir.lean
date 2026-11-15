import Veir.Input
import Veir.Printer
import Veir.Air.Rewrite
import Veir.Air.Instance
import Veir.Air.Channels
import Veir.Air.ChanGlue
import Veir.Air.Aie

/-! # `air-veir`: AIR async programs in VeIR

See `Veir/Air/README.md` for what each command establishes and what it does not. -/

open Veir
open Veir.Air

def usage : String :=
"Usage: air-veir <command> [options] <file> [<file>]

Read MLIR-AIR in MLIR's generic form (`air-opt --mlir-print-op-generic`) and work on its
async events and the memory they touch: functions whose body is air.execute, air.wait_all,
air.dma_memcpy_nd, arith and memref.alloc, with air.execute bodies of arith, memref and
(uninterpreted) linalg operations. Anything else is refused with a diagnostic. See
Veir/Air/SEMANTICS.md for what each construct means here.

Commands:
  graph <file>         print each function's event graph, the edges the
                       transitive reduction keeps, and any read of an execute's
                       result that is not ordered after it
  run <file>           interpret each function: the values every air.execute
                       yields in program order, and whether every finishing
                       order the dependencies allow computes the same thing
  races <file>         print every pair of events that read and write a common
                       element without a token path between them (RAW, WAR,
                       WAW), and problems inside single DMAs; exit 1 if any
  reduce <file>        print the module with each event's dependency operands
                       reduced as air-dependency-canonicalize reduces them
  check <before> <after>
                       check that two versions of a module have the same events
                       and order them identically (sameReach, proven sound in
                       Veir.Air.DepGraph); otherwise print an order one allows
                       and the other forbids
  aie <file>           C6: explore every aie.device (after air-to-aie and
                       airrt-to-npu; Veir/Air/AIE_SEMANTICS.md): every interleaving
                       of locks, DMA transfers, cores and the runtime sequence.
                       Prints a deadlock with a run reaching it, and the distinct
                       outcomes of host memory; exit 1 if either is wrong
  outcome <file>       C6: one complete run's host memory per function, printed as
                       `aie` prints it (for a race-free program, its only outcome)

Options:
  --allow-unregistered-dialect   accept operations VeIR does not register (needed for
                                 air.launch, air.herd, memref.alloc, ...)
  --max-orders=<n>               stop enumerating finishing orders after n (default 100000)
  --max-states=<n>               aie: stop exploring after n states (default 200000)
  --no-por                       aie: explore without partial-order reduction
  --all-outcomes                 aie: print every distinct outcome (default: the first 4)
  --args=<i,j,...>               values of the function's scalar (index, integer) arguments,
                                 in order. `run` uses 0 for missing ones; `races` treats
                                 missing ones as unknown, so the accesses they shape cover
                                 their whole buffer
  --help                         print this message"

structure Args where
  command : String
  files : List String
  allowUnregistered : Bool := false
  maxOrders : Nat := 100000
  maxStates : Nat := 200000
  por : Bool := true
  allOutcomes : Bool := false
  scalarArgs : Option (List Int) := none

def parseArgs (args : List String) : Except String Args := do
  let mut positional : List String := []
  let mut allowUnregistered := false
  let mut maxOrders := 100000
  let mut maxStates := 200000
  let mut por := true
  let mut allOutcomes := false
  let mut scalarArgs : Option (List Int) := none
  for a in args do
    if a == "--allow-unregistered-dialect" then allowUnregistered := true
    else if a.startsWith "--max-orders=" then
      let some n := (a.drop "--max-orders=".length).toString.toNat?
        | throw s!"invalid {a}"
      maxOrders := n
    else if a == "--no-por" then por := false
    else if a == "--all-outcomes" then allOutcomes := true
    else if a.startsWith "--max-states=" then
      let some n := (a.drop "--max-states=".length).toString.toNat?
        | throw s!"invalid {a}"
      maxStates := n
    else if a.startsWith "--args=" then
      let some xs := ((a.drop "--args=".length).toString.splitOn ",").mapM String.toInt?
        | throw s!"invalid {a}"
      scalarArgs := some xs
    else if a.startsWith "-" then throw s!"unknown option {a}"
    else positional := positional ++ [a]
  match positional with
  | command :: files => return { command, files, allowUnregistered, maxOrders, maxStates, por, allOutcomes, scalarArgs }
  | [] => throw "expected a command"

/-- The `func.func`s at the top level of a module. -/
def topLevelFuncs (ctx : IRContext OpCode) (top : OperationPtr) : Array OperationPtr :=
  if top.getNumRegions! ctx = 0 then #[] else
  match (top.getRegion! ctx 0).getFirstBlock! ctx with
  | none => #[]
  | some block => (blockOps ctx block).filter fun op =>
    -- A declaration (`func.func private @f(...)`, no body) has nothing to analyse.
    op.getOpType! ctx == .func .func && ((op.getRegion! ctx 0).getFirstBlock! ctx).isSome

def funcName (ctx : IRContext OpCode) (func : OperationPtr) : String :=
  String.fromUTF8! (func.getProperties! ctx (OpCode.func Func.func)).sym_name.value

/-- VeIR's `arith.constant` holds only integers and `index` (VEIR-004). Rename every
`arith.constant` whose result is not an integer or `index` (floats, dense vectors) to the
unregistered `veir.opaque_constant`, whose value the model treats as opaque (D22). Only lines in
MLIR's generic form are rewritten, and only when VeIR refused the file for this reason. -/
def renameNonIntegerConstants (text : String) : String :=
  "\n".intercalate <| (text.splitOn "\n").map fun line =>
    if (line.splitOn "\"arith.constant\"()").length > 1 then
      let ty := ((line.splitOn "() -> ").getLast?.getD "").trimAscii.toString
      let isInt := ty == "index" || (ty.startsWith "i" && (ty.drop 1).toString.toNat?.isSome)
      if isInt then line else line.replace "\"arith.constant\"()" "\"veir.opaque_constant\"()"
    else line

def load (args : Args) (file : String) : IO (WfIRContext OpCode × OperationPtr) := do
  let content₀ ← IO.FS.readBinFile file
  let floatRefused (e : String) := (e.splitOn "expected 'value' to be an integer or index attribute").length > 1
  -- First try as written; on VEIR-004 retry with non-integer constants renamed.
  let content ← match Veir.Input.parseSourceString content₀ file args.allowUnregistered with
    | .error e =>
      if floatRefused e && args.allowUnregistered then
        IO.eprintln s!"warning: {file}: VeIR's arith.constant holds integers only (VEIR-004); non-integer constants read as opaque values"
        pure (renameNonIntegerConstants (String.fromUTF8! content₀)).toUTF8
      else pure content₀
    | .ok _ => pure content₀
  match Veir.Input.parseSourceString content file args.allowUnregistered with
  | .ok (ctx, top, _) => return (ctx, top)
  | .error e =>
    -- VeIR's verifier refuses `index` operands to arith integer ops, which MLIR allows
    -- (VEIR-003 in ~/air-issues). The model computes on `index` values, so read the program
    -- without VeIR's verifier in that case only, and say so.
    let isIndex := (e.splitOn "to have integer type").length > 1
    -- VeIR does not know that unregistered ops such as aie.next_bd may end a block (VEIR-005).
    let isTerm := (e.splitOn "Expected the last operation of a block to be a terminator").length > 1
    if isIndex || isTerm then
      match Veir.Input.parseSourceString content file args.allowUnregistered (verifyAfterParse := false) with
      | .ok (ctx, top, _) =>
        let why := if isIndex then "rejects arith on index (VEIR-003)"
          else "requires a registered terminator at the end of each block (VEIR-005)"
        IO.eprintln s!"warning: {file}: VeIR's verifier {why}; read without it"
        return (ctx, top)
      | .error _ => throw (IO.userError e)
    else throw (IO.userError e)

def kindName : EventKind → String
  | .execute => "air.execute"
  | .waitAll => "air.wait_all async"
  | .waitAllBlocking => "air.wait_all (blocking)"
  | .dma => "air.dma_memcpy_nd"
  | .dmaBlocking => "air.dma_memcpy_nd (blocking)"
  | .put => "air.channel.put"
  | .putBlocking => "air.channel.put (sync)"
  | .get => "air.channel.get"
  | .getBlocking => "air.channel.get (sync)"
  | .scopeStart => "start of a hierarchy op"
  | .scopeEnd => "end of a hierarchy op"
  | .scopeEndBlocking => "end of a hierarchy op (sync)"
  | .syncOp => "a synchronous op"

/-- Instantiate a function's events (Veir.Air.Instance), with the scalar arguments given. -/
def extractOrThrow (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int := []) :
    IO IProgram := do
  match instantiate ctx func scalars with
  | .ok ip =>
    unless ip.prog.graph.forwardB do
      throw (IO.userError s!"@{funcName ctx func}: the event graph is not topologically numbered")
    return ip
  | .error e => throw (IO.userError s!"@{funcName ctx func}: {e}")

/-- `run` takes missing scalar arguments to be 0. -/
def runScalars (args : Args) : List Int := (args.scalarArgs.getD []) ++ List.replicate 64 0

/-- A value as MLIR would write it. -/
def showValue : RuntimeValue → String
  | .int w (.val b) => s!"{b.toInt} : i{w}"
  | .int w .poison => s!"poison : i{w}"
  | r => toString r

/-- A value as MLIR would write it. -/
def showMemVal : Val → String
  | .rv r => showValue r
  | x => showVal x

/-- What a run computed: each execute's yielded values, the final contents of the argument
buffers, or the fault. -/
def outcome (ip : IProgram) (s : MState) : String :=
  match s.fault with
  | some f => s!"fault: {f}"
  | none =>
    let p := ip.prog
    let parts := (List.range p.events.size).filterMap fun v =>
      let e := p.events[v]!
      if e.kind ≠ .execute || e.yields.isEmpty then none else
        let vals := (List.range e.yields.size).map fun i =>
          match s.results[(v, i + 1)]? with
          | some r => showMemVal r
          | none => "?"
        some s!"event {v} = {vals}"
    let mems := ip.argBufs.toList.map fun b =>
      let buf := ip.buffers[b]!
      let n := buf.type.numel
      let vals := (List.range n).map fun (q : Nat) => showMemVal (s.mem[(b, (q : Int))]?.getD .undef)
      if n ≤ 64 then s!"{buf.name} = {vals}" else s!"{buf.name} = <{n} elements, hash {hash (toString vals) % 1000000}>"
    let all := parts ++ mems
    if all.isEmpty then "no values" else ", ".intercalate all

def cmdGraph (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let ip ← extractOrThrow ctx.raw func (args.scalarArgs.getD [])
    let p := ip.prog
    IO.println s!"@{funcName ctx.raw func}: {p.events.size} event(s)"
    let keep := p.reducedOperands
    for e in p.events, v in [0:p.events.size] do
      let ops := e.operandEvents.toList
      let kept := ((e.operandEvents.zip keep[v]!).filterMap fun (u, k) => if k then some u else none).toList
      IO.println s!"  event {v}{pathStr ip.ctxs[v]!.path}: {kindName e.kind} waits for {ops}, keeps {kept}\
        {if e.implicitDeps.isEmpty then "" else s!", after blocking {e.implicitDeps}"}\
        {if e.dataDeps.isEmpty then "" else s!", reads results of {e.dataDeps}"}"
    for (u, v) in p.unorderedReads do
      IO.println s!"  warning: event {v} reads a result of event {u} without waiting for it"

def cmdRun (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let ip ← extractOrThrow ctx.raw func (runScalars args)
    let name := funcName ctx.raw func
    if ip.chans.isEmpty then
      let run (o : List Nat) := outcome ip (ip.run ctx.raw o)
      let g := ip.prog.graph
      IO.println s!"@{name}: program order: {run (List.range ip.prog.events.size)}"
      let orders := g.orders args.maxOrders
      let outcomes := orders.map fun o => (o, run o)
      let distinct := outcomes.foldl (init := ([] : List String)) fun acc (_, r) =>
        if acc.contains r then acc else acc ++ [r]
      let capped := if orders.length ≥ args.maxOrders then " (enumeration capped)" else ""
      IO.println s!"  {orders.length} finishing order(s) allowed{capped}, {distinct.length} distinct outcome(s)"
      if distinct.length > 1 then
        for r in distinct do
          let some (o, _) := outcomes.find? (·.2 == r) | continue
          IO.println s!"  order {o}: {r}"
    else
      -- With channels: the proven channel model (Veir.Air.ChanSem, ChanMem, ChanGlue).
      let ca ← match ip.analyzeChannels with
        | .ok ca => pure ca
        | .error e => throw (IO.userError s!"@{name}: {e}")
      let cm ← match ip.chanModel ca with
        | .ok cm => pure cm
        | .error e => do IO.println s!"@{name}: not covered: {e}"; continue
      let (fps0, _) := ip.footprints ctx.raw
      let cv := cm.verdict (ip.labelFp ca cm fps0)
      match cv.completes with
      | some false => IO.println s!"@{name}: deadlocks (see `races`)"
      | none => IO.println s!"@{name}: internal error: the proposed execution failed its check"
      | some true =>
        IO.println s!"@{name}: {outcome ip (ip.runLabels ctx.raw ca cm cv.trace)}"
        if cv.raceFree then
          IO.println s!"  race-free: every execution ends with this memory (Chan.outcome_uniqueH)"
        else
          IO.println s!"  races (see `races`): other executions may end differently"

def cmdRaces (args : Args) (file : String) : IO Bool := do
  let (ctx, top) ← load args file
  let mut clean := true
  for func in topLevelFuncs ctx.raw top do
    let ip ← extractOrThrow ctx.raw func (args.scalarArgs.getD [])
    let name := funcName ctx.raw func
    let (fps0, issues) := ip.footprints ctx.raw
    let p := ip.prog
    let eventAt (v : Nat) := s!"event {v}{pathStr ip.ctxs[v]!.path} ({kindName p.events[v]!.kind})"
    -- Without channels: the event graph as it is. With them: the channel orderings added, and
    -- renumbered to be forward (Veir.Air.Channels).
    let mut reports : List RaceReport := []
    let mut chanLines : List String := []
    if ip.chans.isEmpty then
      reports := ip.raceReports fps0
    else
      let ca ← match ip.analyzeChannels with
        | .ok ca => pure ca
        | .error e => throw (IO.userError s!"@{name}: {e}")
      -- D33 and D37 come from the extraction; the rest from the proven channel model.
      chanLines := chanLines ++ ca.errors.map (s!"  error: " ++ ·)
      match ip.chanModel ca with
      | .error e => chanLines := chanLines ++ [s!"  error: not covered: {e}"]
      | .ok cm =>
        let cp := cm.prog
        let labelAt := cm.labelName eventAt
        let fp := ip.labelFp ca cm fps0
        let cv := cm.verdict fp
        let fired : Std.HashSet Chan.Label := Std.HashSet.ofList cv.trace
        match cv.completes with
        | none => chanLines := chanLines ++ ["  internal error: the proposed execution failed its check"]
        | some false =>
          let unfinished := (List.range p.events.size).filter fun v => !fired.contains (.finish v)
          let waiting := (List.range cp.elems.size).filter fun k =>
            match cp.elems[k]? with
            | some e => (List.range e.dsts.length).any (fun i => e.dsts[i]?.join.isSome && !Chan.gotH fired k i) ||
                e.src.isSome && !Chan.sentH fired k
            | none => false
          chanLines := chanLines ++ [s!"  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: {", ".intercalate (unfinished.map eventAt)}"]
          if let some k := waiting.head? then
            chanLines := chanLines ++ [s!"  the first element that never moves: element {cm.pos[k]!} of {cm.slotName[k]!}"]
        | some true =>
          chanLines := chanLines ++ ["  no deadlock (proven, Chan.checkH_true): an execution completes, and every execution can (Chan.completes_from_anywhere)"]
          let arr := cv.trace.toArray
          if !cv.raceFree && cv.witnesses.isEmpty then
            chanLines := chanLines ++ ["  race: the race check failed, and the reporter found no witness"]
          for (i, j) in cv.witnesses do
            let (x, y) := (arr[i]!, arr[j]!)
            let witness := (fp x).findSome? fun a => (fp y).findSome? fun b =>
              if a.conflictsB b then
                let bs : Std.HashSet Int := Std.HashSet.ofList b.elems
                (a.elems.find? bs.contains).map fun e =>
                  let kind := match a.kind, b.kind with
                    | .write, .read => "RAW" | .read, .write => "WAR" | _, _ => "WAW"
                  (kind, if a.buf == ip.slotBuf then "an element in flight" else ip.buffers[a.buf]!.name, e)
              else none
            if let some (kind, buffer, e) := witness then
              chanLines := chanLines ++ [s!"  race: {kind} on {buffer} element {e} between {labelAt x} and {labelAt y}, which no execution order fixes"]
    let raceCount := reports.length + (chanLines.filter (·.startsWith "  race")).length
    IO.println s!"@{name}: {p.events.size} event(s), {ip.buffers.size} buffer(s), \
      {raceCount} race(s), {issues.size} problem(s) inside single events"
    for l in chanLines do IO.println l
    for r in reports do
      IO.println s!"  race: {r.kind} on {r.buffer} element {r.element} between {eventAt r.first} and \
        {eventAt r.second}, with no token path between them"
    for i in issues do
      IO.println s!"  event {i.event}{pathStr ip.ctxs[i.event]!.path}: {i.msg}"
    let chanBad := chanLines.any fun l => l.startsWith "  error" || l.startsWith "  DEADLOCK" ||
      l.startsWith "  internal" || l.startsWith "  races not" || l.startsWith "  race"
    if !reports.isEmpty || !issues.isEmpty || chanBad then clean := false
  return clean

def cmdReduce (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  let mut programs := #[]
  for func in topLevelFuncs ctx.raw top do
    let ip ← extractOrThrow ctx.raw func (args.scalarArgs.getD [])
    if ip.loops > 0 then
      throw (IO.userError s!"@{funcName ctx.raw func}: reduce does not support loops yet; check can validate another tool's rewrite")
    if ip.prog.events.any (·.kind == .scopeStart) then
      throw (IO.userError s!"@{funcName ctx.raw func}: reduce does not support air.launch/segment/herd/rank yet; check can validate another tool's rewrite")
    let p := ip.prog
    -- The checker `sameReach_sound` covers; a `false` here would be a bug in `reducedGraph`.
    unless DepGraph.sameReach p.graph p.reducedGraph do
      throw (IO.userError s!"@{funcName ctx.raw func}: internal error: the reduction changed reachability")
    programs := programs.push p
  -- The context is rewritten in place, so nothing may read `ctx` from here on.
  let mut raw := ctx.raw
  for p in programs do
    raw := p.applyReduction raw
  Veir.Printer.printModule raw top { printGenericOpForm := true }

/-- An order `h` allows and `g` forbids, if the enumeration finds one. -/
def counterexample (g h : DepGraph) (maxOrders : Nat) : Option (List Nat) :=
  (h.orders maxOrders).find? fun o => !g.allowsOrder o

def cmdCheck (args : Args) (before after : String) : IO Bool := do
  let (c1, t1) ← load args before
  let (c2, t2) ← load args after
  let fs1 := topLevelFuncs c1.raw t1
  let fs2 := topLevelFuncs c2.raw t2
  if fs1.size ≠ fs2.size then
    IO.println s!"FAIL: {fs1.size} function(s) before, {fs2.size} after"
    return false
  let mut ok := true
  for f1 in fs1, f2 in fs2 do
    let name := funcName c1.raw f1
    let ip1 ← extractOrThrow c1.raw f1 (args.scalarArgs.getD [])
    let ip2 ← extractOrThrow c2.raw f2 (args.scalarArgs.getD [])
    let p1 := ip1.prog
    let p2 := ip2.prog
    if p1.events.size ≠ p2.events.size then
      IO.println s!"FAIL @{name}: {p1.events.size} event(s) before, {p2.events.size} after"
      ok := false; continue
    let mut same := true
    for e1 in p1.events, e2 in p2.events, v in [0:p1.events.size] do
      if e1.kind ≠ e2.kind || e1.body.size ≠ e2.body.size || e1.yields.size ≠ e2.yields.size ||
          e1.dataDeps ≠ e2.dataDeps || e1.implicitDeps ≠ e2.implicitDeps then
        IO.println s!"FAIL @{name}: event {v} changed other than in its dependency operands"
        same := false
    if !same then ok := false; continue
    if DepGraph.sameReach p1.graph p2.graph then
      IO.println s!"OK @{name}: {p1.events.size} event(s), same reachability \
        ({p1.graph.preds.foldl (· + ·.length) 0} edge(s) before, \
        {p2.graph.preds.foldl (· + ·.length) 0} after)"
    else
      ok := false
      IO.println s!"FAIL @{name}: the dependency graphs order the events differently"
      if let some o := counterexample p1.graph p2.graph args.maxOrders then
        IO.println s!"  the second allows finishing order {o}, which the first forbids"
        IO.println s!"  running that order: {outcome ip1 (ip1.run c1.raw o)}"
      if let some o := counterexample p2.graph p1.graph args.maxOrders then
        IO.println s!"  the first allows finishing order {o}, which the second forbids"
  return ok

/-- Values as runs: consecutive integers `a..b`, repeated values `v x n`. -/
def runs (vs : List Val) : String :=
  let rec go (acc : List String) (xs : List Val) : String := match xs with
    | [] => ", ".intercalate acc.reverse
    | v :: rest =>
      match v.toInt? with
      | some a =>
        let n := (rest.zip (List.range rest.length)).takeWhile (fun (w, k) => w.toInt? == some (a + k + 1)) |>.length
        if n ≥ 2 then go (s!"{a}..{a + n}" :: acc) (rest.drop n)
        else
          let m := rest.takeWhile (· == v) |>.length
          if m ≥ 2 then go (s!"{showVal v} x {m + 1}" :: acc) (rest.drop m) else go (showVal v :: acc) rest
      | none =>
        let m := rest.takeWhile (· == v) |>.length
        if m ≥ 1 then go (s!"{showVal v} x {m + 1}" :: acc) (rest.drop m) else go (showVal v :: acc) rest
  termination_by xs.length
  decreasing_by all_goals simp_wf; all_goals (try simp [List.length_drop]); all_goals omega
  go [] vs

/-- The host arguments' final contents, as `runs`; the same format as `aie` prints. -/
def hostOutcome (ip : IProgram) (s : MState) : String :=
  match s.fault with
  | some f => s!"fault: {f}"
  | none =>
    let parts := (ip.argBufs.toList.zip (List.range ip.argBufs.size)).map fun (b, j) =>
      let n := ip.buffers[b]!.type.numel
      s!"%arg{j} = [{runs ((List.range n).map fun (q : Nat) => s.mem[(b, (Int.ofNat q))]?.getD .undef)}]"
    ", ".intercalate parts

/-- C6 phase 2: one complete run's host memory. For a program `races` finds race-free and
deadlock-free, it is the only outcome (`deterministic`, C3). -/
def cmdOutcome (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let ip ← extractOrThrow ctx.raw func (runScalars args)
    let name := funcName ctx.raw func
    if ip.chans.isEmpty then
      IO.println s!"@{name}: {hostOutcome ip (ip.run ctx.raw (List.range ip.prog.events.size))}"
    else
      let ca ← match ip.analyzeChannels with
        | .ok ca => pure ca
        | .error e => throw (IO.userError s!"@{name}: {e}")
      let cm ← match ip.chanModel ca with
        | .ok cm => pure cm
        | .error e => do IO.println s!"@{name}: not covered: {e}"; continue
      let cv := cm.verdict (fun _ => []) (checkRaces := false)
      match cv.completes with
      | some true => IO.println s!"@{name}: {hostOutcome ip (ip.runLabels ctx.raw ca cm cv.trace)}"
      | some false => IO.println s!"@{name}: deadlocks"
      | none => IO.println s!"@{name}: internal error: the proposed execution failed its check"

/-- C6: explore every `aie.device` (AIE_SEMANTICS.md, `Veir.Air.Aie`). -/
def cmdAie (args : Args) (file : String) : IO Bool := do
  let (ctx, top) ← load args file
  let mut ok := true
  let some mb := (top.getRegion! ctx.raw 0).getFirstBlock! ctx.raw | return true
  for d in blockOps ctx.raw mb do
    if opName ctx.raw d != "aie.device" then continue
    let name := match findProp (unregProps ctx.raw d) "sym_name" with
      | some (.stringAttr s) => String.fromUTF8! s.value
      | _ => "?"
    match Aie.extract ctx.raw d with
    | .error e =>
      IO.println s!"@{name}: refused: {e}"
      ok := false
    | .ok m =>
      let r := m.explore args.maxStates args.por
      IO.println s!"@{name}: {m.chans.size} DMA channel(s), {m.cores.size} core(s), {m.locks.size} lock(s), \
        {m.tasks.size} task(s); {r.states} state(s){if r.complete then "" else " (bound reached)"}"
      match r.deadlock with
      | some tr =>
        ok := false
        IO.println s!"  DEADLOCK: the runtime sequence cannot finish; a run reaching it ({tr.size} step(s)):"
        for l in tr.toList.drop (tr.size - min tr.size 12) do IO.println s!"    {l}"
      | none => IO.println "  no deadlock"
      if let some (f, tr) := r.fault then
        ok := false
        IO.println s!"  FAULT: {f} (after {tr.size} step(s))"
      IO.println s!"  {r.outcomes.size} distinct outcome(s) of host memory"
      for o in (if args.allOutcomes then r.outcomes.toList else r.outcomes.toList.take 4) do
        let parts := (m.hostArgs.toList.zip o.toList).map fun (b, vs) =>
          s!"{m.buffers[b]!.1} = [{runs vs.toList}]"
        IO.println s!"    {", ".intercalate parts}"
      if r.outcomes.size > 1 then ok := false
  return ok

def main (argv : List String) : IO UInt32 := do
  if argv.contains "--help" || argv.contains "-h" then
    IO.println usage
    return 0
  match parseArgs argv with
  | .error e =>
    IO.eprintln s!"error: {e}\n\n{usage}"
    return 2
  | .ok args =>
    try
      match args.command, args.files with
      | "graph", [f] => cmdGraph args f; return 0
      | "run", [f] => cmdRun args f; return 0
      | "reduce", [f] => cmdReduce args f; return 0
      | "races", [f] => return if ← cmdRaces args f then 0 else 1
      | "check", [a, b] => return if ← cmdCheck args a b then 0 else 1
      | "aie", [f] => return if ← cmdAie args f then 0 else 1
      | "outcome", [f] => cmdOutcome args f; return 0
      | _, _ =>
        IO.eprintln s!"error: bad command line\n\n{usage}"
        return 2
    catch e =>
      IO.eprintln s!"error: {e}"
      return 1
