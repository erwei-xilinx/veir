module

public import Veir.Air.Events
public import Veir.Dialects.Air.OpInfo
public import Veir.Interpreter.Basic

namespace Veir.Air

@[expose] public section

/-! # From an AIR function to an event program

`extract` reads one `func.func` whose body is a straight-line block of `air.execute`,
`air.wait_all` and `arith.constant` operations, and returns its event graph together with what each
event does. It refuses -- with a message naming the operation -- everything it cannot give a
faithful meaning to, rather than reading it as a no-op:

* any other operation in the function body, in particular `air.launch`, `air.segment`, `air.herd`,
  `scf.for` and `scf.parallel`: they open a scope whose instances, loop-carried tokens or
  hierarchy this model has no events for;
* any operation other than `arith` inside an `air.execute`, in particular `memref.alloc`,
  `memref.dealloc` and `linalg`: memory is not modelled;
* a token that is a block argument, comes from an unsupported operation, or is used before it is
  defined;
* an `air.execute` whose terminator does not yield exactly the values the operation declares.
  AIR's verifier does not check this.

## What an event does

An event is one `air.execute` or `air.wait_all`, numbered in program order. `air.wait_all` does
nothing; `air.execute` runs its body, in order, when it finishes, and makes the values it yields
available to other events from then on. Reading the result of an execute that has not finished is
a *fault*, not a stale or default value: the operation that reads it does not wait for it.

A blocking `air.wait_all` (one with no result) stops the host from issuing anything after it until
its dependencies are done. That is an ordering no operand states, so `Event.implicitDeps` makes
every later event wait for it. The rewrite in `reducedOperands` may not remove these edges, since
they are not operands; `steps_between_iff` is the theorem that covers keeping them.

`arith.constant` in the function body is evaluated before any event, as the host does before it
issues the first one. `func.return` is not an event, and what it means for events still
outstanding is undecided (`SEMANTICS.md`, D5); a complete trace runs every event to completion.

Every choice above about what AIR means is recorded, with whether an AIR developer has confirmed
it, in `Veir/Air/SEMANTICS.md`.
-/

inductive EventKind where
  | execute
  | waitAll
  /-- `air.wait_all` with no result: the host waits for it before issuing anything else. -/
  | waitAllBlocking
deriving DecidableEq, Repr, Inhabited

structure Event where
  op : OperationPtr
  kind : EventKind
  /-- The event each operand is the token of, in operand order. -/
  operandEvents : Array Nat
  /-- The blocking `air.wait_all`s issued before this event. -/
  implicitDeps : List Nat
  /-- The events whose results the body reads. -/
  dataDeps : List Nat
  /-- An `air.execute`'s body, without its terminator. -/
  body : Array OperationPtr
  /-- What an `air.execute`'s terminator yields. -/
  yields : Array ValuePtr
deriving Inhabited

structure Program where
  func : OperationPtr
  events : Array Event
  /-- The `arith.constant`s in the function body. -/
  hostOps : Array OperationPtr
deriving Inhabited

/-- The program's dependency graph: the operands of each event, and the blocking waits before it. -/
def Program.graph (p : Program) : DepGraph :=
  ⟨p.events.map fun e => e.operandEvents.toList ++ e.implicitDeps⟩

/-! ### Extraction -/

/-- An operation's name as written, including that of an unregistered operation. -/
def opName (ctx : IRContext OpCode) (op : OperationPtr) : String :=
  match op.getOpType! ctx with
  | .builtin .unregistered =>
    String.fromUTF8! (op.getProperties! ctx (OpCode.builtin Builtin.unregistered)).opName
  | opType => String.fromUTF8! (IsOpCode.name opType)

/-- The operations of a block, in order. -/
def blockOps (ctx : IRContext OpCode) (block : BlockPtr) : Array OperationPtr := Id.run do
  let mut ops := #[]
  let mut cur := block.getFirstOp! ctx
  -- The operation list is a linked list; the arena size bounds the walk.
  for _ in List.range (ctx.operations.size + 1) do
    match cur with
    | none => break
    | some op =>
      ops := ops.push op
      cur := op.getNextOp! ctx
  return ops

/-- The single block of a single-region operation. -/
def singleBlock (ctx : IRContext OpCode) (op : OperationPtr) (what : String) :
    Except String BlockPtr := do
  if op.getNumRegions! ctx ≠ 1 then
    throw s!"{what}: expected exactly one region"
  let region := op.getRegion! ctx 0
  let some block := region.getFirstBlock! ctx
    | throw s!"{what}: expected a non-empty region"
  if region.getLastBlock! ctx ≠ some block then
    throw s!"{what}: control flow between blocks is not supported"
  return block

structure ExtractState where
  eventOf : Std.HashMap OperationPtr Nat := {}
  hostOf : Std.HashSet OperationPtr := {}
  events : Array Event := #[]
  hostOps : Array OperationPtr := #[]
  blocking : List Nat := []

/-- The event whose token `v` is. -/
def tokenEvent (ctx : IRContext OpCode) (st : ExtractState) (what : String) (v : ValuePtr) :
    Except String Nat := do
  match v with
  | .blockArgument _ =>
    throw s!"{what}: a token that is a block argument is not supported; tokens must come from \
      an air.execute or air.wait_all in the same block"
  | .opResult ⟨d, i⟩ =>
    if let some e := st.eventOf[d]? then
      if i = 0 then return e
      throw s!"{what}: operand is result #{i} of event {e}, which is not its token"
    match d.getOpType! ctx with
    | .air .execute | .air .wait_all =>
      throw s!"{what}: uses the token of a later {opName ctx d}; a dependency on an event \
        defined below is a cycle or a graph region, and is not supported"
    | _ =>
      throw s!"{what}: a token produced by '{opName ctx d}' is not supported"

/-- Read an `air.execute`'s body, checking that it computes with `arith` alone and yields what the
operation declares. Returns the body, the yielded values and the events it reads results of. -/
def executeBody (ctx : IRContext OpCode) (st : ExtractState) (op : OperationPtr)
    (what : String) : Except String (Array OperationPtr × Array ValuePtr × List Nat) := do
  let block ← singleBlock ctx op what
  if block.getNumArguments! ctx ≠ 0 then
    throw s!"{what}: expected a body without block arguments"
  let ops := blockOps ctx block
  let some term := ops.back?
    | throw s!"{what}: expected a terminator"
  let .air .execute_terminator := term.getOpType! ctx
    | throw s!"{what}: expected the body to end in air.execute_terminator"
  let body := ops.pop
  let mut inBody : Std.HashSet OperationPtr := {}
  let mut dataDeps : List Nat := []
  for inner in body ++ #[term] do
    if inner != term then
      let .arith _ := inner.getOpType! ctx
        | throw s!"{what}: '{opName ctx inner}' in an air.execute body is not supported; only \
            arith operations have a meaning here (memory is not modelled)"
      if inner.getNumRegions! ctx ≠ 0 then
        throw s!"{what}: '{opName ctx inner}' has a region, which is not supported"
    for v in inner.getOperands! ctx do
      match v with
      | .blockArgument _ =>
        throw s!"{what}: '{opName ctx inner}' reads a block argument, which is not supported"
      | .opResult ⟨d, i⟩ =>
        if inBody.contains d || st.hostOf.contains d then continue
        match st.eventOf[d]? with
        | some e =>
          if i = 0 then
            throw s!"{what}: '{opName ctx inner}' uses a token as a value, which is not supported"
          if !dataDeps.contains e then dataDeps := dataDeps ++ [e]
        | none =>
          throw s!"{what}: '{opName ctx inner}' reads a value of '{opName ctx d}', which is not \
            supported"
    inBody := inBody.insert inner
  let yields := term.getOperands! ctx
  let results := op.getResultTypes! ctx
  let yieldTypes := term.getOperandTypes! ctx
  if yields.size + 1 ≠ results.size then
    throw s!"{what}: the terminator yields {yields.size} value(s), but the operation declares \
      {results.size - 1}"
  for i in [0:yields.size] do
    if yieldTypes[i]! != results[i + 1]! then
      throw s!"{what}: the terminator yields {yieldTypes[i]!} as value #{i}, but the operation \
        declares {results[i + 1]!}"
  return (body, yields, dataDeps)

/-- Read a `func.func` as an event program. See the header for what is refused. -/
def extract (ctx : IRContext OpCode) (func : OperationPtr) : Except String Program := do
  let .func .func := func.getOpType! ctx
    | throw s!"expected a func.func, but got '{opName ctx func}'"
  let block ← singleBlock ctx func "func.func"
  let ops := blockOps ctx block
  let mut st : ExtractState := {}
  for op in ops, idx in [0:ops.size] do
    let what := s!"operation #{idx} ('{opName ctx op}')"
    match op.getOpType! ctx with
    | .air .execute | .air .wait_all =>
      let id := st.events.size
      let operandEvents ← (op.getOperands! ctx).mapM (tokenEvent ctx st what)
      let isExecute := op.getOpType! ctx == .air .execute
      let kind :=
        if isExecute then EventKind.execute
        else if op.getNumResults! ctx = 0 then EventKind.waitAllBlocking
        else EventKind.waitAll
      let (body, yields, dataDeps) ←
        if isExecute then executeBody ctx st op what else pure (#[], #[], [])
      st := { st with
        eventOf := st.eventOf.insert op id
        events := st.events.push
          { op, kind, operandEvents, implicitDeps := st.blocking, dataDeps, body, yields } }
      if kind = EventKind.waitAllBlocking then
        st := { st with blocking := st.blocking ++ [id] }
    | .arith .constant =>
      st := { st with hostOf := st.hostOf.insert op, hostOps := st.hostOps.push op }
    | .func .return =>
      if idx + 1 ≠ ops.size then throw s!"{what}: expected func.return to be last"
    | _ =>
      if op.getNumRegions! ctx ≠ 0 then
        throw s!"{what}: '{opName ctx op}' opens a nested region or scope, which is not \
          supported"
      throw s!"{what}: '{opName ctx op}' is not supported in a function body"
  return { func, events := st.events, hostOps := st.hostOps }

/-- Events that read a result of another event without (transitively) waiting for it. Each is a
data race: some schedule runs the reader first, and `finishEvent` reports the fault. -/
def Program.unorderedReads (p : Program) : List (Nat × Nat) :=
  (List.range p.events.size).flatMap fun v =>
    p.events[v]!.dataDeps.filterMap fun u => if p.graph.reachB u v then none else some (u, v)

/-! ### Executable semantics -/

/-- The values computed so far, and the first fault, if there was one. -/
structure RunState where
  values : Std.HashMap ValuePtr RuntimeValue := {}
  fault : Option String := none
deriving Inhabited

/-- Run one `arith` operation. -/
def evalArith (ctx : IRContext OpCode) (op : OperationPtr) (operands : Array RuntimeValue) :
    Except String (Array RuntimeValue) :=
  match op.getOpType! ctx with
  | .arith a =>
    match Arith.interpretOp' a (op.getProperties! ctx (OpCode.arith a))
        (op.getResultTypes! ctx) operands #[] with
    | .ok (results, _) => .ok results
    | .ub _ => .error s!"'{opName ctx op}' has undefined behaviour"
    | .fail _ => .error s!"'{opName ctx op}' could not be interpreted"
  | _ => .error s!"'{opName ctx op}' is not an arith operation"

/-- The host's constants, before any event starts. -/
def Program.initState (ctx : IRContext OpCode) (p : Program) : RunState := Id.run do
  let mut st : RunState := {}
  for op in p.hostOps do
    match evalArith ctx op #[] with
    | .ok results =>
      for r in results, i in [0:results.size] do
        st := { st with values := st.values.insert (.opResult ⟨op, i⟩) r }
    | .error msg => return { st with fault := some msg }
  return st

/-- What finishing event `v` does to the state: run an `air.execute`'s body and publish what it
yields; nothing for `air.wait_all`. A fault is sticky. -/
def Program.finishEvent (ctx : IRContext OpCode) (p : Program) (v : Nat) (s : RunState) :
    RunState := Id.run do
  if s.fault.isSome then return s
  let some e := p.events[v]? | return { s with fault := some s!"event {v} does not exist" }
  if e.kind ≠ .execute then return s
  let mut vals := s.values
  for inner in e.body do
    let mut args := #[]
    for operand in inner.getOperands! ctx do
      match vals[operand]? with
      | some r => args := args.push r
      | none =>
        let msg := match operand with
          | .opResult ⟨d, _⟩ => s!"event {v} read a result of '{opName ctx d}' before it was \
              available"
          | .blockArgument _ => s!"event {v} read a block argument"
        return { s with fault := some msg }
    match evalArith ctx inner args with
    | .ok results =>
      for r in results, i in [0:results.size] do
        vals := vals.insert (.opResult ⟨inner, i⟩) r
    | .error msg => return { s with fault := some s!"event {v}: {msg}" }
  let mut out := s.values
  for y in e.yields, i in [0:e.yields.size] do
    match vals[y]? with
    | some r => out := out.insert (.opResult ⟨e.op, i + 1⟩) r
    | none =>
      return { s with fault := some s!"event {v} yields a value that was not available" }
  return { s with values := out }

/-- The program's semantics, as an instance of `Veir.Air.Sem`: starting an event does nothing, and
finishing it is `finishEvent`. `steps_reduce_iff` therefore holds of it. -/
def Program.sem (ctx : IRContext OpCode) (p : Program) : Sem RunState where
  onStart _ s s' := s' = s
  onFinish v s s' := s' = p.finishEvent ctx v s

/-- **The AIR instance of the main theorem.** For an extracted program whose graph is forward,
reducing its dependencies admits exactly the same executions -- the same values, the same faults
-- as the original. -/
theorem Program.steps_reduce_iff (ctx : IRContext OpCode) (p : Program) (hf : p.graph.Forward)
    {t : List Label} {c : Config RunState} :
    Steps p.graph.reduce (p.sem ctx) (Config.init (p.initState ctx)) t c ↔
      Steps p.graph (p.sem ctx) (Config.init (p.initState ctx)) t c :=
  Veir.Air.steps_reduce_iff hf

/-! ### Running schedules

`Steps` admits every interleaving of starts and finishes. Since starting an event has no effect
here, what a run computes depends only on the order in which events finish; these functions run a
given finishing order, and enumerate the orders the graph allows. -/

/-- Whether `order` lists every event once, each after everything it waits for. -/
def DepGraph.allowsOrder (g : DepGraph) (order : List Nat) : Bool :=
  order.length == g.size && order.Nodup && Id.run do
    let mut seen : Std.HashSet Nat := {}
    for v in order do
      if v ≥ g.size || !(g.predsOf v).all seen.contains then return false
      seen := seen.insert v
    return true

/-- Finish the events in `order`, one after another. -/
def Program.runOrder (ctx : IRContext OpCode) (p : Program) (order : List Nat) : RunState :=
  order.foldl (fun s v => p.finishEvent ctx v s) (p.initState ctx)

/-- Every finishing order the graph allows, up to `limit` of them. -/
partial def DepGraph.orders (g : DepGraph) (limit : Nat := 100000) : List (List Nat) :=
  (go [] (List.range g.size) #[]).toList
where
  go (done : List Nat) (todo : List Nat) (acc : Array (List Nat)) : Array (List Nat) :=
    if acc.size ≥ limit then acc
    else if todo.isEmpty then acc.push done.reverse
    else
      todo.foldl (init := acc) fun acc v =>
        if (g.predsOf v).all done.contains then go (v :: done) (todo.erase v) acc else acc

/-! ### The rewrite -/

/-- For each event, which of its operands `air-dependency-canonicalize`'s reduction keeps. An edge
from a blocking `air.wait_all` that is also an operand may be dropped: the implicit edge stays. -/
def Program.reducedOperands (p : Program) : Array (Array Bool) :=
  let g := p.graph
  p.events.mapIdx fun v e => e.operandEvents.map fun u => g.keepEdge u v

/-- The graph `reducedOperands` leaves: the kept operands, and every implicit edge. -/
def Program.reducedGraph (p : Program) : DepGraph :=
  let keep := p.reducedOperands
  ⟨p.events.mapIdx fun v e =>
    ((e.operandEvents.zip keep[v]!).filterMap fun (u, k) => if k then some u else none).toList
      ++ e.implicitDeps⟩

end

end Veir.Air
