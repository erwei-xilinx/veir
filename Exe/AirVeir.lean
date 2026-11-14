import Veir.Input
import Veir.Printer
import Veir.Air.Rewrite

/-! # `air-veir`: AIR async programs in VeIR

See `Veir/Air/README.md` for what each command establishes and what it does not. -/

open Veir
open Veir.Air

def usage : String :=
"Usage: air-veir <command> [options] <file> [<file>]

Read MLIR-AIR in MLIR's generic form (`air-opt --mlir-print-op-generic`) and work on the
async-event subset: functions whose body is air.execute, air.wait_all and arith.constant, with
arith-only air.execute bodies. Anything else is refused with a diagnostic.

Commands:
  graph <file>         print each function's event graph, the edges the
                       transitive reduction keeps, and any read of an execute's
                       result that is not ordered after it
  run <file>           interpret each function: the values every air.execute
                       yields in program order, and whether every finishing
                       order the dependencies allow computes the same thing
  reduce <file>        print the module with each event's dependency operands
                       reduced as air-dependency-canonicalize reduces them
  check <before> <after>
                       check that two versions of a module have the same events
                       and order them identically (sameReach, proven sound in
                       Veir.Air.DepGraph); otherwise print an order one allows
                       and the other forbids

Options:
  --allow-unregistered-dialect   accept operations VeIR does not register (needed for
                                 air.launch, air.herd, memref.alloc, ...)
  --max-orders=<n>               stop enumerating finishing orders after n (default 100000)
  --help                         print this message"

structure Args where
  command : String
  files : List String
  allowUnregistered : Bool := false
  maxOrders : Nat := 100000

def parseArgs (args : List String) : Except String Args := do
  let mut positional : List String := []
  let mut allowUnregistered := false
  let mut maxOrders := 100000
  for a in args do
    if a == "--allow-unregistered-dialect" then allowUnregistered := true
    else if a.startsWith "--max-orders=" then
      let some n := (a.drop "--max-orders=".length).toString.toNat?
        | throw s!"invalid {a}"
      maxOrders := n
    else if a.startsWith "-" then throw s!"unknown option {a}"
    else positional := positional ++ [a]
  match positional with
  | command :: files => return { command, files, allowUnregistered, maxOrders }
  | [] => throw "expected a command"

/-- The `func.func`s at the top level of a module. -/
def topLevelFuncs (ctx : IRContext OpCode) (top : OperationPtr) : Array OperationPtr :=
  if top.getNumRegions! ctx = 0 then #[] else
  match (top.getRegion! ctx 0).getFirstBlock! ctx with
  | none => #[]
  | some block => (blockOps ctx block).filter fun op => op.getOpType! ctx == .func .func

def funcName (ctx : IRContext OpCode) (func : OperationPtr) : String :=
  String.fromUTF8! (func.getProperties! ctx (OpCode.func Func.func)).sym_name.value

def load (args : Args) (file : String) : IO (WfIRContext OpCode × OperationPtr) := do
  let content ← IO.FS.readBinFile file
  match Veir.Input.parseSourceString content file args.allowUnregistered with
  | .ok (ctx, top, _) => return (ctx, top)
  | .error e => throw (IO.userError e)

def kindName : EventKind → String
  | .execute => "air.execute"
  | .waitAll => "air.wait_all async"
  | .waitAllBlocking => "air.wait_all (blocking)"

def extractOrThrow (ctx : IRContext OpCode) (func : OperationPtr) : IO Program := do
  match extract ctx func with
  | .ok p =>
    unless p.graph.forwardB do
      throw (IO.userError s!"@{funcName ctx func}: the event graph is not topologically numbered")
    return p
  | .error e => throw (IO.userError s!"@{funcName ctx func}: {e}")

/-- A value as MLIR would write it. -/
def showValue : RuntimeValue → String
  | .int w (.val b) => s!"{b.toInt} : i{w}"
  | .int w .poison => s!"poison : i{w}"
  | r => toString r

/-- An execute's yielded values, or the fault, after a run. -/
def outcome (p : Program) (s : RunState) : String :=
  match s.fault with
  | some f => s!"fault: {f}"
  | none =>
    let parts := (List.range p.events.size).filterMap fun v =>
      let e := p.events[v]!
      if e.kind ≠ .execute || e.yields.isEmpty then none else
        let vals := (List.range e.yields.size).map fun i =>
          match s.values[ValuePtr.opResult ⟨e.op, i + 1⟩]? with
          | some r => showValue r
          | none => "?"
        some s!"event {v} = {vals}"
    if parts.isEmpty then "no values" else ", ".intercalate parts

def cmdGraph (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let p ← extractOrThrow ctx.raw func
    IO.println s!"@{funcName ctx.raw func}: {p.events.size} event(s)"
    let keep := p.reducedOperands
    for e in p.events, v in [0:p.events.size] do
      let ops := e.operandEvents.toList
      let kept := ((e.operandEvents.zip keep[v]!).filterMap fun (u, k) => if k then some u else none).toList
      IO.println s!"  event {v}: {kindName e.kind} waits for {ops}, keeps {kept}\
        {if e.implicitDeps.isEmpty then "" else s!", after blocking {e.implicitDeps}"}\
        {if e.dataDeps.isEmpty then "" else s!", reads results of {e.dataDeps}"}"
    for (u, v) in p.unorderedReads do
      IO.println s!"  warning: event {v} reads a result of event {u} without waiting for it"

def cmdRun (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  for func in topLevelFuncs ctx.raw top do
    let p ← extractOrThrow ctx.raw func
    let g := p.graph
    let programOrder := List.range p.events.size
    IO.println s!"@{funcName ctx.raw func}: program order: {outcome p (p.runOrder ctx.raw programOrder)}"
    let orders := g.orders args.maxOrders
    let outcomes := orders.map fun o => (o, outcome p (p.runOrder ctx.raw o))
    let distinct := outcomes.foldl (init := ([] : List String)) fun acc (_, r) =>
      if acc.contains r then acc else acc ++ [r]
    let capped := if orders.length ≥ args.maxOrders then " (enumeration capped)" else ""
    IO.println s!"  {orders.length} finishing order(s) allowed{capped}, {distinct.length} distinct outcome(s)"
    if distinct.length > 1 then
      for r in distinct do
        let some (o, _) := outcomes.find? (·.2 == r) | continue
        IO.println s!"  order {o}: {r}"

def cmdReduce (args : Args) (file : String) : IO Unit := do
  let (ctx, top) ← load args file
  let mut programs := #[]
  for func in topLevelFuncs ctx.raw top do
    let p ← extractOrThrow ctx.raw func
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
    let p1 ← extractOrThrow c1.raw f1
    let p2 ← extractOrThrow c2.raw f2
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
        IO.println s!"  running that order: {outcome p1 (p1.runOrder c1.raw o)}"
      if let some o := counterexample p2.graph p1.graph args.maxOrders then
        IO.println s!"  the first allows finishing order {o}, which the second forbids"
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
      | "check", [a, b] => return if ← cmdCheck args a b then 0 else 1
      | _, _ =>
        IO.eprintln s!"error: bad command line\n\n{usage}"
        return 2
    catch e =>
      IO.eprintln s!"error: {e}"
      return 1
