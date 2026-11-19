module

public import Veir.Air.ChanGlue
public import Veir.Air.ChanDecide

namespace Veir.Air

@[expose] public section

/-! # D59: instantiating while running

A loop bound or branch condition computed by events is a decision (`Instance.controlEnv`). The
program is instantiated in rounds:
1. instantiate with the values decided so far; a decision whose value is not known cuts what it
   controls, and the rest of its instance, which waits for it (D60);
2. run that partial program (the execution `Chan.genTrace` proposes, as far as it goes) and take
   the values the pending decisions read;
3. repeat until nothing is pending.

The rounds only *propose* values; nothing about them is proven. The whole program they end with
is then checked: if it completes and is race-free, `Chan.decision_reads` proves that every
execution, at each decision, reads the value the instantiation used (`decisionsOk` checks its
hypotheses). If not, the verdicts are those of the program with these values, and whether every
execution takes this control flow is not established.

Trusted (not proven): that the program instantiated with the right values is the program run on
that input, as D59 says.
-/

/-- How many rounds of instantiation are allowed. -/
def maxRounds : Nat := 1000

/-- The values the pending decisions of a partial program read, from the execution
`Chan.genTrace` proposes. Decisions whose results are not computed in it are left out. -/
def IProgram.proposeValues (ctx : IRContext OpCode) (ip : IProgram) :
    Except String (List (ResultKey × Int)) := do
  let ca ← ip.analyzeChannels
  let orders ← ip.putOrders ca
  let some o := orders.head? | throw "no order of puts"
  let cm ← ip.chanModel ca o
  let t := cm.someTrace
  let s := ip.runLabels ctx ca cm t
  let mut out : List (ResultKey × Int) := []
  for d in ip.decides ++ ip.offsets do
    if d.values.isSome then continue
    let vals := d.reads.map fun r => (ip.resultKeys[r]?, s.results[r]? >>= Val.toInt?)
    if vals.all fun (k, n) => k.isSome && n.isSome then
      for (k, n) in vals do
        out := out ++ [(k.get!, n.get!)]
  return out

/-- The hypotheses of `Chan.decision_reads` for every decision, on a complete execution `t` and
the state `s` it ends with: results are written only by their events (`soleWritersB`), each
decision fires after the events it reads and reads their results, and those results are the
values the instantiation used. -/
def ChanModel.decisionsOk (cm : ChanModel) (ip : IProgram) (fp : Chan.LFp) (t : List Chan.Label)
    (s : MState) : Bool :=
  let B := ip.resultBuf
  let pos := Chan.positions t
  Chan.soleWritersB fp (Chan.cands cm.prog) B &&
  (ip.decides.all fun d =>
    match d.values with
    | none => false
    | some ns => (d.reads.zip ns).all fun ((e, i), n) =>
      Chan.lwritesB fp (.finish e) (B, Int.ofNat e) &&
      Chan.lreadsB fp (.finish d.event) (B, Int.ofNat e) &&
      (match pos[Chan.Label.finish e]?, pos[Chan.Label.finish d.event]? with
       | some a, some b => decide (a < b) && t[a]? == some (.finish e) &&
           t[b]? == some (.finish d.event)
       | _, _ => false) &&
      (s.results[(e, i)]? >>= Val.toInt?) == some n) &&
  -- D62: a transfer reads its offsets' results as it starts. One still pending is
  -- over-approximated (D23) and needs nothing here.
  ip.offsets.all fun d =>
    match d.values with
    | none => true
    | some ns => (d.reads.zip ns).all fun ((e, i), n) =>
      Chan.lwritesB fp (.finish e) (B, Int.ofNat e) &&
      Chan.lreadsB fp (.start d.event) (B, Int.ofNat e) &&
      (match pos[Chan.Label.finish e]?, pos[Chan.Label.start d.event]? with
       | some a, some b => decide (a < b) && t[a]? == some (.finish e) &&
           t[b]? == some (.start d.event)
       | _, _ => false) &&
      (s.results[(e, i)]? >>= Val.toInt?) == some n

/-- What the decisions of the whole program are known to be. -/
inductive DecisionStatus where
  | none
  /-- Checked on every model (one per order of puts, D52): `Chan.decision_reads` applies. -/
  | proven (n : Nat)
  | notEstablished (n : Nat) (why : String)
  /-- No value could be proposed for a decision: the program is instantiated only up to the
  decisions not known (`IProgram.complete` is false); the string names the first. -/
  | undetermined (what : String)

/-- Instantiate with run-time control flow (D59). Returns the whole program, how many rounds it
took, and what is known of its decisions. -/
partial def instantiateRunning (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int)
    (argData : Std.HashMap Nat (Array Int)) (sampleN : Option Nat := none)
    (zeroLoops : List SymKey := []) : Except String (IProgram × Nat × DecisionStatus) := do
  let rec go (decisions : Std.HashMap ResultKey Int) (round : Nat) :
      Except String (IProgram × Nat × DecisionStatus) := do
    if round > maxRounds then
      throw s!"more than {maxRounds} rounds of run-time control flow (D59)"
    let ip ← instantiate ctx func scalars decisions sampleN zeroLoops
    let ip := { ip.sizeBarePointers ctx with argData }
    if ip.decides.isEmpty && ip.offsets.isEmpty then return (ip, round, .none)
    let offsetsPending := ip.offsets.any (·.values.isNone)
    if !ip.complete || offsetsPending then
      -- Only offsets pending: a model that cannot be built (D33) leaves them over-approximated.
      let vals ← if ip.complete then pure ((ip.proposeValues ctx).toOption.getD [])
        else ip.proposeValues ctx
      let fresh := vals.filter fun (k, _) => !decisions.contains k
      if !fresh.isEmpty then
        return ← go (fresh.foldl (fun m (k, n) => m.insert k n) decisions) (round + 1)
      if let some d := ip.decides.find? (·.values.isNone) then
        let ev := ip.prog.events[d.event]!
        return (ip, round, .undetermined s!"'{opName ctx ev.op}'{pathStr ip.ctxs[d.event]!.path}")
      -- Only offsets are pending and none can be proposed: they stay over-approximated (D23).
    -- The whole program: check the decisions on every model.
    let n := ip.decides.size + (ip.offsets.filter (·.values.isSome)).size
    -- No value instantiated (every offset stays over-approximated): nothing to check or report.
    if n == 0 then return (ip, round, .none)
    -- With transfer values only (D62), a model that cannot be built is reported by the verdicts
    -- themselves; the values are then those of one execution.
    let models := do let ca ← ip.analyzeChannels; return (ca, ← ip.putOrders ca)
    let (ca, orders) ← match models with
      | .ok r => pure r
      | .error e => if ip.decides.isEmpty then return (ip, round, .notEstablished n e) else throw e
    let (fps0, _) := ip.footprints ctx
    let mut why : Option String := none
    for o in orders do
      let cm ← ip.chanModel ca o
      let fp := ip.labelFp ca cm fps0
      let cv := cm.verdict fp
      if cv.completes != some true then
        why := why <|> some "the program does not complete"
        continue
      if !cv.raceFree then
        why := why <|> some "the program has a race"
        continue
      let s := ip.runLabels ctx ca cm cv.trace
      if cm.decisionsOk ip fp cv.trace s then continue
      -- The values proposed were not those the execution computes: take those, and redo.
      let mut fixed := decisions
      let mut changed := false
      for d in ip.decides ++ ip.offsets do
        for r in d.reads, used in d.values.getD [] do
          if let (some k, some x) := (ip.resultKeys[r]?, s.results[r]? >>= Val.toInt?) then
            if x != used then
              fixed := fixed.insert k x
              changed := true
      if changed then return ← go fixed (round + 1)
      why := why <|> some "the decisions' check failed"
    match why with
    | none => return (ip, round, .proven n)
    | some w => return (ip, round, .notEstablished n w)
  go {} 0

end

end Veir.Air
