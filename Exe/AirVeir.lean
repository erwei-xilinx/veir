import Veir.Input
import Veir.Printer
import Veir.Air.Rewrite
import Veir.Air.Instance
import Veir.Air.Channels
import Veir.Air.ChanGlue
import Veir.Air.AieCert
import Veir.Air.Running
import Veir.Air.LoopTemplate

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
                       WAW), and problems inside single DMAs; exit 1 if any.
                       A function whose loop bounds are not known, or that is
                       too large to instantiate, is checked through a loop
                       template: race-free for every trip count, or the pair
                       not established (phase 2a)
  template <file>      print each function's loop template (phase 2a): its
                       events, edges and footprints, and the certificate
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
  --no-por                       aie: never fall back to partial-order reduction
  --all-outcomes                 aie: print every distinct outcome (default: the first 4)
  --args=<i,j,...>               values of the function's scalar (index, integer) arguments,
                                 in order. `run` uses 0 for missing ones; `races` treats
                                 missing ones as unknown, so the accesses they shape cover
                                 their whole buffer
  --mem=<i>:<v,v,...>            contents of the i-th memref argument (counting memref
  --mem=<i>@<file>               arguments only), as integers; from a file, separated by
                                 commas or white space. Loop bounds and branch conditions
                                 computed on the device from them are followed (D59); the
                                 verdicts hold for that input
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
  /-- `--mem` options, as given. -/
  memSpecs : List String := []
  /-- Contents of memref arguments, by position among the memref arguments (D59), read from
  `memSpecs` by `loadArgData`. -/
  argData : Std.HashMap Nat (Array Int) := {}

/-- Integers separated by commas, spaces or newlines. -/
def parseInts (txt : String) : Option (Array Int) :=
  let words := (txt.split fun c => c == ',' || c == ' ' || c == '\n' || c == '\t' || c == '\r').toList
  ((words.map (·.toString)).filter (· ≠ "")).toArray.mapM String.toInt?

def parseArgs (args : List String) : Except String Args := do
  let mut positional : List String := []
  let mut allowUnregistered := false
  let mut maxOrders := 100000
  let mut maxStates := 200000
  let mut por := true
  let mut allOutcomes := false
  let mut scalarArgs : Option (List Int) := none
  let mut memSpecs : List String := []
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
    else if a.startsWith "--mem=" then
      -- `--mem=<i>:<v,v,...>` or `--mem=<i>@<file>`, read below.
      memSpecs := memSpecs ++ [(a.drop "--mem=".length).toString]
    else if a.startsWith "-" then throw s!"unknown option {a}"
    else positional := positional ++ [a]
  match positional with
  | command :: files => return { command, files, allowUnregistered, maxOrders, maxStates, por, allOutcomes, scalarArgs,
                                 memSpecs }
  | [] => throw "expected a command"

/-- Read `--mem=<i>:<v,v,...>` and `--mem=<i>@<file>`: the contents of the `i`-th memref argument. -/
def loadArgData (args : Args) : IO Args := do
  let mut data : Std.HashMap Nat (Array Int) := {}
  for m in args.memSpecs do
    let (iTxt, rest, fromFile) := match m.splitOn "@", m.splitOn ":" with
      | i :: r, _ => if i.toNat?.isSome && !r.isEmpty then (i, "@".intercalate r, true) else
          match m.splitOn ":" with
          | [i, r] => (i, r, false)
          | _ => ("", "", false)
      | _, _ => ("", "", false)
    let some i := iTxt.toNat? | throw (IO.userError s!"invalid --mem={m}: expected <i>:<values> or <i>@<file>")
    let txt ← if fromFile then IO.FS.readFile rest else pure rest
    let some vs := parseInts txt | throw (IO.userError s!"invalid --mem={m}: expected integers")
    data := data.insert i vs
  return { args with argData := data }

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
  | .issue => "air.channel.issue"
  | .issueBlocking => "air.channel.issue (sync)"
  | .decide => "control-flow decision"

/-- Instantiate a function's events (Veir.Air.Instance), with the scalar arguments given. -/
def extractOrThrow (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int := []) :
    IO IProgram := do
  match instantiate ctx func scalars with
  | .ok ip =>
    let ip := ip.sizeBarePointers ctx
    unless ip.prog.graph.forwardB do
      throw (IO.userError s!"@{funcName ctx func}: the event graph is not topologically numbered")
    unless ip.decides.isEmpty do
      throw (IO.userError s!"@{funcName ctx func}: control flow on values events compute (D59) is \
        supported by races, run and outcome only")
    return ip
  | .error e => throw (IO.userError s!"@{funcName ctx func}: {e}")

/-- Instantiate with run-time control flow (D59, `Veir.Air.Running`), on the memref contents given;
also returns the line saying what is known of the decisions, if there are any. -/
def extractRunning (args : Args) (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int)
    (partialOk : Bool := false) : IO (IProgram × Option String) := do
  let name := funcName ctx func
  match instantiateRunning ctx func scalars args.argData with
  | .error e => throw (IO.userError s!"@{name}: {e}")
  | .ok (ip, _, status) =>
    unless ip.prog.graph.forwardB do
      throw (IO.userError s!"@{name}: the event graph is not topologically numbered")
    for (j, vs) in args.argData.toList do
      let some b := ip.argBufs[j]? | throw (IO.userError s!"@{name}: --mem={j}: there are {ip.argBufs.size} memref argument(s)")
      let t := ip.buffers[b]!.type
      if t.bitwidth == 0 then throw (IO.userError s!"@{name}: --mem={j}: only integer buffers can be given")
      -- A bare pointer (D63) takes any length; positions past the values given hold 0.
      if !t.unranked && vs.size != t.numel then
        throw (IO.userError s!"@{name}: --mem={j}: {vs.size} value(s) for {t.numel} element(s)")
    let values (d : Decision) : String :=
      let ev := ip.prog.events[d.event]!
      let vs := (d.reads.zip (d.values.getD [])).map fun ((e, _), n) => s!"event {e} = {n}"
      s!"'{opName ctx ev.op}'{pathStr ip.ctxs[d.event]!.path} ({", ".intercalate vs})"
    let all := ip.decides ++ ip.offsets.filter (·.values.isSome)
    let shown := (all.toList.take 6).map values
    let more := if all.size > 6 then s!", and {all.size - 6} more" else ""
    -- D59 decisions and D62 transfer values, counted apart.
    let kinds := s!"{ip.decides.size} control-flow decision(s), {all.size - ip.decides.size} transfer value(s) (D62)"
    if let .undetermined what := status then
      if !partialOk then
        throw (IO.userError s!"@{name}: {what}: the value deciding it (D59) is not computed in the \
          execution proposed for the part of the program before it (see `races`)")
    let line := match status with
      | .none => none
      | .undetermined what => some s!"  control flow on values events compute (D59): the value deciding \
          {what} is not computed in the execution proposed for the part of the program before it. \
          Below, the verdicts for that part alone, instantiated up to the decisions not known; a \
          deadlock there may come from what those decisions control, which is left out"
      | .proven _ => some s!"  values events compute, read by control flow (D59) and transfers (D62): {kinds}: \
          {"; ".intercalate shown}{more}. Every execution reads these values (proven, Chan.decision_reads)"
      | .notEstablished _ why => some s!"  values events compute, read by control flow (D59) and transfers (D62): {kinds}: \
          {"; ".intercalate shown}{more}. These are the values one execution computes; that every \
          execution reads them is not established ({why}), so the verdicts below are for this control flow"
    return (ip, line)

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

/-- The orders chosen for puts no token orders (D52), for messages. -/
def orderDesc (o : List (StreamKey × List Nat)) : String :=
  "; ".intercalate (o.filterMap fun ((c, _, _), evs) =>
    if evs.length > 1 then some s!"@{c}: events {evs}" else none)

def cmdRun (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let (ip, dline) ← extractRunning args ctx.raw func (runScalars args)
    let name := funcName ctx.raw func
    -- The proven model (Veir.Air.ChanSem, ChanMem, ChanFast), built by Veir.Air.ChanGlue.
    let ca ← match ip.analyzeChannels with
      | .ok ca => pure ca
      | .error e => throw (IO.userError s!"@{name}: {e}")
    let orders ← match ip.putOrders ca with
      | .ok os => pure os
      | .error e => do IO.println s!"@{name}: not covered: {e}"; continue
    let (fps0, _) := ip.footprints ctx.raw
    let eventAt (v : Nat) := s!"event {v}{pathStr ip.ctxs[v]!.path} ({kindName ip.prog.events[v]!.kind})"
    -- D52: one model per order of the puts no token orders; the program's executions are all of
    -- theirs.
    let mut lines : List String := []
    let mut outcomes : List (String × String) := []
    let mut header : Option String := none
    for o in orders do
      let tag := if orders.length > 1 then s!" [puts in order {orderDesc o}]" else ""
      let cm ← match ip.chanModel ca o with
        | .ok cm => pure cm
        | .error e => do header := header <|> some s!"not covered: {e}"; continue
      let cv := cm.verdict (ip.labelFp ca cm fps0)
      match cv.completes with
      | some false => header := header <|> some s!"deadlocks{tag} (see `races`)"
      | none => header := header <|> some s!"internal error: the proposed execution failed its check{tag}"
      | some true =>
        let first := outcome ip (ip.runLabels ctx.raw ca cm cv.trace)
        if !outcomes.any (·.1 == first) then outcomes := outcomes ++ [(first, tag)]
        if cv.raceFree then
          let via := if cv.chunks.isSome then " [on chunks: Chan.outcome_uniqueC]" else ""
          lines := lines ++ [s!"  race-free: every execution ends with this memory (Chan.outcome_uniqueH){tag}{via}"]
        else
          match cv.alt with
          | none => lines := lines ++ [s!"  races (see `races`): other executions may end differently{tag}"]
          | some (x, y, t2) =>
            let second := outcome ip (ip.runLabels ctx.raw ca cm t2)
            let names := cm.labelName eventAt
            if second == first then
              lines := lines ++ [s!"  races (see `races`); an execution with {names y} before {names x} ends the same{tag}"]
            else
              lines := lines ++ [s!"  races (see `races`); an execution with {names y} before {names x} ends differently: {second}{tag}"]
    match header with
    | some h => IO.println s!"@{name}: {h}"
    | none =>
      IO.println s!"@{name}: {(outcomes.head?.map (·.1)).getD "no outcome"}"
      if let some l := dline then IO.println l
      for l in lines.eraseDups do IO.println l
      for (o, tag) in outcomes.drop 1 do
        IO.println s!"  another order of puts ends differently (D52): {o}{tag}"

/-- What `races` reports for one model (one order of the puts, D52): its proven verdicts. -/
def raceLines (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis) (cm : ChanModel)
    (fps0 : Array (List Access)) (eventAt : Nat → String) : List String := Id.run do
  let p := ip.prog
  let _ := ctx
  let mut out : List String := []
  let cp := cm.prog
  let labelAt := cm.labelName eventAt
  let fp := ip.labelFp ca cm fps0
  let cv := cm.verdict fp
  let fired : Std.HashSet Chan.Label := Std.HashSet.ofList cv.trace
  match cv.completes with
  | none => out := out ++ ["  internal error: the proposed execution failed its check"]
  | some false =>
    let unfinished := (List.range p.events.size).filter fun v => !fired.contains (.finish v)
    let waiting := (List.range cp.elems.size).filter fun k =>
      match cp.elems[k]? with
      | some e => (List.range e.dsts.length).any (fun i => e.dsts[i]?.join.isSome && !Chan.gotH fired k i) ||
          e.src.isSome && !Chan.sentH fired k
      | none => false
    let via := match cv.chunks with
      | some (n, m) => s!" [on {n} chunks of {m} elements: Chan.chunked_deadlock]"
      | none => ""
    out := out ++ [s!"  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: {", ".intercalate (unfinished.map eventAt)}{via}"]
    if let some k := waiting.head? then
      out := out ++ [s!"  the first element that never moves: element {cm.pos[k]!} of {cm.slotName[k]!}"]
    -- Why, when the streams are unbalanced (a fragment of a program, D34).
    let noPut := (List.range cp.elems.size).filter fun k => (cp.elems[k]?.map (·.src.isNone)).getD false
    let noGet := (List.range cp.elems.size).filter fun k => match cp.elems[k]? with
      | some e => e.src.isSome && !e.buffered && e.dsts.any (·.isNone)
      | none => false
    if !noPut.isEmpty then
      out := out ++ [s!"  note: {noPut.length} element(s) that gets wait for no put provides"]
    if !noGet.isEmpty then
      out := out ++ [s!"  note: {noGet.length} element(s) of async puts no get takes (D34)"]
  | some true =>
    let via := match cv.chunks with
      | some (n, m) => s!" [on {n} chunks of {m} elements: Chan.chunked_sound]"
      | none => ""
    out := out ++ [s!"  no deadlock (proven, Chan.checkH_true): an execution completes, and every execution can (Chan.completes_from_anywhere){via}"]
    -- Elements of sync puts that nothing gets stay in the buffer (D30): a fragment of a program.
    let orphans := (List.range cp.elems.size).filter fun k => match cp.elems[k]? with
      | some e => e.src.isSome && e.buffered && e.dsts.any (·.isNone)
      | none => false
    if !orphans.isEmpty then
      out := out ++ [s!"  note: {orphans.length} element(s) of sync puts are never got (buffered, D30)"]
    let arr := cv.trace.toArray
    let mut seen : Std.HashSet (Nat × Nat × String) := {}
    if !cv.raceFree && cv.witnesses.isEmpty then
      out := out ++ ["  race: the race check failed, and the reporter found no witness"]
    for (i, j) in cv.witnesses do
      -- Name the pair in event (program) order, not in the order this execution fired it.
      let (x, y) := if cm.owner arr[j]! < cm.owner arr[i]! then (arr[j]!, arr[i]!) else (arr[i]!, arr[j]!)
      let witness := (fp x).findSome? fun a => (fp y).findSome? fun b =>
        if a.conflictsB b then
          let bs : Std.HashSet Int := Std.HashSet.ofList b.elems
          (a.elems.find? bs.contains).map fun e =>
            let kind := match a.kind, b.kind with
              | .write, .read => "RAW" | .read, .write => "WAR" | _, _ => "WAW"
            (kind, if a.buf == ip.slotBuf then "an element in flight"
              else if a.buf == ip.resultBuf then "the results of an event"
              else ip.buffers[a.buf]!.name, e)
        else none
      if let some (kind, buffer, e) := witness then
        -- One message per pair of events and buffer.
        let key := (cm.owner x, cm.owner y, buffer)
        if !seen.contains key then
          seen := seen.insert key
          out := out ++ [s!"  race: {kind} on {buffer} element {e} between {labelAt x} and {labelAt y}, which no execution order fixes"]
  return out

/-- Phase 2a: when a function cannot be instantiated (a loop bound not known, or too many
instances), race-freedom for every trip count of its symbolic loops, from a loop template
(`LoopTemplate`, trusted) and its certificate (`LoopCert.raceFree_of_certOk`, proven). `none`
when there is no template to try. -/
def templateVerdict (ctx : IRContext OpCode) (func : OperationPtr) (name : String) (scalars : List Int)
    (why : String) : IO (Option Bool) := do
  match LoopTemplate.template ctx func scalars with
  | .ok none => return none
  | .error e =>
    IO.println s!"@{name}: {why}; no loop template either: {e}"
    return some false
  | .ok (some (T, s)) =>
    let what (t : Nat) : String :=
      match (List.range s.tev.size).find? (s.tev[·]! == t) with
      | some v => s!"'{opName ctx s.ip.prog.events[v]!.op}'"
      | none => s!"template event {t}"
    if T.certOk then
      IO.println s!"@{name}: {T.loops.size} template event(s), {T.nl} symbolic loop(s): race-free for \
        every trip count of the symbolic loops (proven, LoopCert.raceFree_of_certOk; the template is \
        extracted, LoopTemplate). Deadlock is not checked (phase 2b)"
      return some true
    else
      let detail := match LoopTemplate.firstFailure T with
        | some (v, w, σ) =>
          let reg := ", ".intercalate (σ.map fun ((L, o) : Nat × Ordering) =>
            s!"loop {L}: {match (o : Ordering) with | .lt => "earlier" | .eq => "same" | .gt => "later"} iteration")
          s!": {what v} and {what w}{if reg.isEmpty then "" else s!" ({reg})"} are neither ordered nor disjoint"
        | none => ""
      IO.println s!"@{name}: {T.loops.size} template event(s), {T.nl} symbolic loop(s): race-freedom for \
        every trip count not established{detail}"
      return some false

/-- Print each function's loop template (phase 2a): its events, edges, footprints and the closure's
size, and the first pair the certificate does not establish. -/
def cmdTemplate (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let name := funcName ctx.raw func
    let t0 ← IO.monoMsNow
    match LoopTemplate.template ctx.raw func (args.scalarArgs.getD []) with
    | .error e => IO.println s!"@{name}: no template: {e}"
    | .ok none => IO.println s!"@{name}: no symbolic loop"
    | .ok (some (T, s)) =>
      IO.println s!"@{name}: {T.nl} symbolic loop(s), {T.loops.size} template event(s), \
        {T.edges.length} edge(s), extracted in {(← IO.monoMsNow) - t0} ms"
      let t1 ← IO.monoMsNow
      let nf := T.facts.length
      IO.println s!"  closure: {nf} fact(s) in {(← IO.monoMsNow) - t1} ms"
      let t2 ← IO.monoMsNow
      let ok := T.certOk
      IO.println s!"  certificate: {ok} in {(← IO.monoMsNow) - t2} ms"
      for t in [0:T.loops.size] do
        let v? := (List.range s.tev.size).find? (s.tev[·]! == t)
        let desc := match v? with
          | some v => s!"'{opName ctx.raw s.ip.prog.events[v]!.op}' (event {v}{pathStr s.ip.ctxs[v]!.path})"
          | none => "?"
        IO.println s!"  t{t}: {desc}, loops {T.loops[t]!}"
        for a in T.fps[t]! do
          IO.println s!"    {if a.write then "writes" else "reads"} b{a.buf} coef {a.coef} \
            {a.offs.size} position(s) from {a.offs[0]?.getD 0}"
      for f in T.edges do
        IO.println s!"  edge t{f.src} -> t{f.dst} {repr f.pat} guard {f.guard}"
      IO.println s!"  {T.facts.length} fact(s) after closure; certificate: {T.certOk}"
      if let some (v, w, σ) := LoopTemplate.firstFailure T then
        IO.println s!"  first failure: t{v}, t{w}, region {σ.map fun ((L, o) : Nat × Ordering) => (L, repr o)}"

def cmdRaces (args : Args) (file : String) : IO Bool := do
  let (ctx, top) ← load args file
  let mut clean := true
  for func in topLevelFuncs ctx.raw top do
    let name := funcName ctx.raw func
    let res ← (extractRunning args ctx.raw func (args.scalarArgs.getD []) (partialOk := true)).toBaseIO
    let (ip, dline) ← match res with
      | .ok r => pure r
      | .error e =>
        let why := toString e
        if (why.splitOn "a loop bound is not known").length > 1 ||
            (why.splitOn "too large to instantiate").length > 1 then
          match ← templateVerdict ctx.raw func name (args.scalarArgs.getD []) why with
          | some ok =>
            if !ok then clean := false
            continue
          | none => throw e
        else throw e
    let (fps0, issues) := ip.footprints ctx.raw
    let p := ip.prog
    let eventAt (v : Nat) := s!"event {v}{pathStr ip.ctxs[v]!.path} ({kindName p.events[v]!.kind})"
    -- Every verdict comes from the proven model (Veir.Air.ChanSem, ChanMem, ChanFast, ChanGlue).
    let mut reports : List RaceReport := []
    let mut chanLines : List String := []
    let ca ← match ip.analyzeChannels with
      | .ok ca => pure ca
      | .error e => throw (IO.userError s!"@{name}: {e}")
    -- D33 and D37 come from the extraction; the rest from the proven channel model.
    chanLines := chanLines ++ ca.errors.map (s!"  error: " ++ ·)
    match ip.putOrders ca with
    | .error e => chanLines := chanLines ++ [s!"  error: not covered: {e}"]
    | .ok orders =>
      -- D52: one model per order of the puts no token orders; the program is all of them.
      let many := orders.length > 1
      if many then
        chanLines := chanLines ++ [s!"  {orders.length} orders of puts that no token orders (D52); each is checked"]
      for o in orders do
        match ip.chanModel ca o with
        | .error e => chanLines := chanLines ++ [s!"  error: not covered: {e}"]
        | .ok cm =>
          let ls := raceLines ctx.raw ip ca cm fps0 eventAt
          chanLines := chanLines ++ (if many then ls.map (· ++ s!" [puts in order {orderDesc o}]") else ls)
    let raceCount := reports.length + (chanLines.filter (·.startsWith "  race")).length
    IO.println s!"@{name}: {p.events.size} event(s), {ip.buffers.size} buffer(s), \
      {raceCount} race(s), {issues.size} problem(s) inside single events"
    if let some l := dline then IO.println l
    for l in chanLines do IO.println l
    for r in reports do
      IO.println s!"  race: {r.kind} on {r.buffer} element {r.element} between {eventAt r.first} and \
        {eventAt r.second}, with no token path between them"
    for i in issues do
      IO.println s!"  event {i.event}{pathStr ip.ctxs[i.event]!.path}: {i.msg}"
    unless ip.branches.isEmpty do
      let parts := ip.branches.toList.zipIdx.map fun ((n, k, rs), i) =>
        s!"#{i} {n} took {rs} of {k} region(s)"
      IO.println s!"  branches reached by this input (coverage, not a verdict): {"; ".intercalate parts}"
    let chanBad := chanLines.any fun l => l.startsWith "  error" || l.startsWith "  DEADLOCK" ||
      l.startsWith "  internal" || l.startsWith "  races not" || l.startsWith "  race"
    if !reports.isEmpty || !issues.isEmpty || chanBad || !ip.complete then clean := false
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
    let (ip, _) ← extractRunning args ctx.raw func (runScalars args)
    let name := funcName ctx.raw func
    let ca ← match ip.analyzeChannels with
      | .ok ca => pure ca
      | .error e => throw (IO.userError s!"@{name}: {e}")
    let orders ← match ip.putOrders ca with
      | .ok os => pure os
      | .error e => do IO.println s!"@{name}: not covered: {e}"; continue
    -- D52: every order of the puts no token orders.
    let mut outs : List String := []
    let mut bad : Option String := none
    for o in orders do
      let cm ← match ip.chanModel ca o with
        | .ok cm => pure cm
        | .error e => do bad := bad <|> some s!"not covered: {e}"; continue
      let cv := cm.verdict (fun _ => []) (checkRaces := false)
      match cv.completes with
      | some true =>
        let r := hostOutcome ip (ip.runLabels ctx.raw ca cm cv.trace)
        if !outs.contains r then outs := outs ++ [r]
      | some false => bad := bad <|> some "deadlocks"
      | none => bad := bad <|> some "internal error: the proposed execution failed its check"
    match bad with
    | some b => IO.println s!"@{name}: {b}"
    | none => IO.println s!"@{name}: {" | ".intercalate outs}"

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
      -- The exploration proposes a certificate; Veir.Air.AieCert checks it.
      -- First without partial-order reduction, which can prove completeness; if that hits the
      -- bound, with it, which can still find reachable verdicts.
      let (c, hitLimit, usedPor) :=
        let (c, h) := m.exploreCert args.maxStates false
        if h && args.por then
          let (c', h') := m.exploreCert args.maxStates true
          (c', h', true)
        else (c, h, false)
      let parentsOk := c.parentsB m
      let closed := !hitLimit && c.closedB m
      IO.println s!"@{name}: {m.chans.size} DMA channel(s), {m.cores.size} core(s), {m.locks.size} lock(s), \
        {m.tasks.size} task(s); {c.states.size} state(s){if hitLimit then " (bound reached)" else ""}"
      if !parentsOk then
        IO.println "  internal error: the exploration's certificate failed its check"
        ok := false
        continue
      IO.println (if closed then
          "  proven (AieCert.Cert.exact): these are exactly the reachable states, so the verdicts below are complete"
        else if usedPor then
          "  every verdict below is reachable (AieCert.Cert.parents_sound); completeness rests on partial-order reduction, which is not proven"
        else
          "  every verdict below is reachable (AieCert.Cert.parents_sound); the bound was reached, so there may be more")
      let finals := (List.range c.states.size).filter fun i => (m.post c.states[i]!).isEmpty
      let deadlocks := finals.filter fun i => c.states[i]!.fault.isNone && c.states[i]!.rtPc < m.runtime.size
      let faults := finals.filter fun i => c.states[i]!.fault.isSome
      let mut outcomes : Array (Array (Array Val)) := #[]
      for i in finals do
        let st := c.states[i]!
        if st.fault.isNone && st.rtPc ≥ m.runtime.size then
          let host := m.hostArgs.map (st.mem[·]!)
          if !outcomes.contains host then outcomes := outcomes.push host
      match deadlocks.head? with
      | some i =>
        ok := false
        let tr := c.traceTo m i
        IO.println s!"  DEADLOCK: the runtime sequence cannot finish; a run reaching it ({tr.size} step(s)):"
        for l in tr.toList.drop (tr.size - min tr.size 12) do IO.println s!"    {l}"
      | none => IO.println "  no deadlock"
      if let some i := faults.head? then
        ok := false
        IO.println s!"  FAULT: {c.states[i]!.fault.getD ""} (after {(c.traceTo m i).size} step(s))"
      IO.println s!"  {outcomes.size} distinct outcome(s) of host memory"
      for o in (if args.allOutcomes then outcomes.toList else outcomes.toList.take 4) do
        let parts := (m.hostArgs.toList.zip o.toList).map fun (b, vs) =>
          s!"{m.buffers[b]!.1} = [{runs vs.toList}]"
        IO.println s!"    {", ".intercalate parts}"
      if outcomes.size > 1 then ok := false
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
      let args ← loadArgData args
      match args.command, args.files with
      | "graph", [f] => cmdGraph args f; return 0
      | "run", [f] => cmdRun args f; return 0
      | "reduce", [f] => cmdReduce args f; return 0
      | "races", [f] => return if ← cmdRaces args f then 0 else 1
      | "template", [f] => cmdTemplate args f; return 0
      | "check", [a, b] => return if ← cmdCheck args a b then 0 else 1
      | "aie", [f] => return if ← cmdAie args f then 0 else 1
      | "outcome", [f] => cmdOutcome args f; return 0
      | _, _ =>
        IO.eprintln s!"error: bad command line\n\n{usage}"
        return 2
    catch e =>
      IO.eprintln s!"error: {e}"
      return 1
