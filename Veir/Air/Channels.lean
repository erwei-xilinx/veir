module

public import Veir.Air.Instance
public import Veir.Air.Schedule

namespace Veir.Air

@[expose] public section

/-! # Layer 4: channels

The semantics is `SEMANTICS.md` D28–D35:
- a subchannel (a channel and its indices) is an ordered stream of elements (D28, D34);
- the i-th element put is the i-th element got, whatever the puts' and gets' sizes (D34);
- endpoints on one subchannel in one direction must be totally ordered by tokens (D33);
- broadcasting sends each put to every destination of the broadcast, or, with `dest`, to the one
  it selects (D29);
- a transfer is buffered if either end is sync, and a rendezvous if both are async (D30);
- padding works as in D20 for puts, and fills the padded destination positions with zeros for
  gets (D31).

**Deadlock.** Whether a program can run to completion is a question about an AND-graph of start
and finish nodes (`Veir.Air.Schedule`). Either answer comes with a certificate checked by a
proven checker:
- a schedule (`scheduleB_sound`);
- or a stuck set (`no_schedule_of_stuckB`).

**Races.** A get's effects happen after the put that feeds it has started, so after everything
that put waited for. If the transfer is buffered, they also happen after the put itself.
Those are the only orderings channels add for races.
-/

/-- A get's padded destination positions, in order, each marked if it is padding (written zero)
rather than taken from the stream (D31). -/
def paddedDst (base : Int) : List (Dim × Nat × Nat) → List (Int × Bool)
  | [] => [(base, false)]
  | (d, b, a) :: ds =>
    (List.range (b + d.size + a)).flatMap fun (k : Nat) =>
      let inner := paddedDst (base + (d.offset + k) * d.stride) ds
      if k < b || k ≥ b + d.size then inner.map fun (p, _) => (p, true) else inner

/-- The subchannels a put feeds (D29). -/
def feedSlots (d : ChanDecl) (idx : List Int) (dest : Option Int) : Except String (List (List Int)) := do
  match d.broadcast with
  | none =>
    if dest.isSome then throw s!"@{d.name}: `dest` needs a channel with broadcast_shape"
    return [idx]
  | some b =>
    if b.length != d.size.length || idx.length != d.size.length then
      throw s!"@{d.name}: broadcast_shape, size and indices differ in rank"
    let bdims := ((d.size.zip b).zipIdx.filter fun ((s, bb), _) => s == 1 && bb > 1).map (·.2)
    if dest.isSome && bdims.length != 1 then
      throw s!"@{d.name}: `dest` needs exactly one broadcast dimension"
    let choices ← ((d.size.zip b).zip idx).zipIdx.mapM fun (((s, bb), i), dim) => do
      if s == bb then pure [i]
      else if s == 1 then
        match dest with
        | some x => if bdims.contains dim then pure [x] else pure [i]
        | none => pure ((List.range bb).map Int.ofNat)
      else throw s!"@{d.name}: size {s} cannot broadcast to {bb}"
    return choices.foldr (init := [[]]) fun opts acc => opts.flatMap fun o => acc.map (o :: ·)

structure Endpoint where
  event : Nat
  isPut : Bool
  sync : Bool
  chan : String
  slot : List Int
  /-- The subchannels it feeds (a put) or reads (a get: just its own). -/
  feeds : List (List Int)
  /-- A put's stream (`none` is a padded zero); empty for a get. -/
  stream : List (Option Int) := []
  /-- A get's padded destination positions; empty for a put. -/
  dst : List (Int × Bool) := []
  buf : Nat
deriving Inhabited

def Endpoint.count (e : Endpoint) : Nat :=
  if e.isPut then e.stream.length else (e.dst.filter (!·.2)).length

/-- Where element `m` of a subchannel's stream comes from and goes to. -/
structure Transfer where
  put : Nat
  putIdx : Nat
  get : Nat
  getIdx : Nat

structure ChanAnalysis where
  endpoints : Std.HashMap Nat Endpoint
  /-- D33 violations, and stream imbalances. -/
  errors : List String
  warnings : List String
  /-- Start/finish AND-graph: node `2e` starts event `e`, `2e + 1` finishes it; the last node
  never fires. -/
  andGraph : DepGraph
  /-- Orderings channels add for races: `u` happens before `v`. Nodes `≥ n` (the number of events)
  are the transfer events of `xfers`, in order. -/
  raceEdges : List (Nat × Nat)
  /-- For each get, its elements' sources. -/
  transfers : Std.HashMap Nat (Array Transfer)
  /-- The transfer events: a put reading the elements one get receives (D36). -/
  xfers : Array (Nat × Nat) := #[]
  /-- Problems inside one transfer: a location read after it may already be written (D36(a)). -/
  xferIssues : List String := []

/-- The endpoint of a channel event, from what is known before running. -/
def IProgram.endpoint (ip : IProgram) (v : Nat) : Except String (Option Endpoint) := do
  let some info := ip.chans[v]? | return none
  let c := ip.ctxs[v]!
  let e := ip.prog.events[v]!
  let what := s!"event {v}{pathStr c.path} (@{info.chan})"
  let some decl := ip.chanDecls[info.chan]? | throw s!"{what}: undeclared channel"
  let bufOfH (h : HVal) : Option Nat := match h with
    | .val (.buf b) => some b
    | .result e i => ip.resultBufs[(e, i)]?
    | _ => none
  let some buf := c.env[info.side.memref]? >>= bufOfH | throw s!"{what}: unknown buffer"
  let t := ip.buffers[buf]!.type
  let entries (xs : Array (Int ⊕ ValuePtr)) : Except String (Array Int) :=
    match xs.mapM fun | .inl n => some n | .inr vp => (c.env[vp]? >>= fun | .val x => x.toInt? | _ => none) with
    | some a => pure a
    | none => throw s!"{what}: a channel transfer's pattern must be known before running"
  let dims ← sidePositions t (← entries info.side.offsets) (← entries info.side.sizes) (← entries info.side.strides)
  let sync := e.kind == .putBlocking || e.kind == .getBlocking
  if info.isPut then
    let stream ← srcStream dims info.padBefore info.padAfter
    checkBounds t ip.buffers[buf]!.name (stream.filterMap id)
    return some { event := v, isPut := true, sync, chan := info.chan, slot := info.indices,
                  feeds := ← feedSlots decl info.indices info.dest, stream, buf }
  else
    let dst :=
      if info.padBefore.isEmpty then (positions dims).map (·, false)
      else paddedDst 0 (dims.zip ((info.padBefore.toList.map Int.toNat).zip (info.padAfter.toList.map Int.toNat)))
    if !info.padBefore.isEmpty && info.padBefore.size != dims.length then
      throw s!"{what}: padding rank differs from the pattern's"
    checkBounds t ip.buffers[buf]!.name (dst.map (·.1))
    return some { event := v, isPut := false, sync, chan := info.chan, slot := info.indices,
                  feeds := [info.indices], dst, buf }

def IProgram.analyzeChannels (ip : IProgram) : Except String ChanAnalysis := do
  let p := ip.prog
  let g := p.graph
  let rows := g.reachRows
  let n := p.events.size
  let mut eps : Std.HashMap Nat Endpoint := {}
  for v in [0:n] do
    if let some ep ← ip.endpoint v then eps := eps.insert v ep
  let mut errors : List String := []
  let mut warnings : List String := []
  -- D33: one subchannel, one direction: totally ordered by tokens.
  let list := (List.range n).filterMap fun v => eps[v]?
  for a in list do
    for b in list do
      if a.event < b.event && a.chan == b.chan && a.isPut == b.isPut && a.slot == b.slot &&
          !g.reachFast rows a.event b.event then
        errors := errors ++ [s!"channel order race (D33): two {if a.isPut then "puts" else "gets"} on @{a.chan}{a.slot} (events {a.event} and {b.event}) with no token path between them"]
  -- The never-firing node, and the AND-graph's base edges.
  let never := 2 * n
  let mut preds : Array (List Nat) := Array.replicate (2 * n + 1) []
  for e in p.events, v in [0:n] do
    preds := preds.set! (2 * v) ((e.operandEvents.toList ++ e.implicitDeps).map (2 * · + 1))
    preds := preds.set! (2 * v + 1) [2 * v]
  preds := preds.set! never [never]
  let mut raceEdges : List (Nat × Nat) := []
  let mut xfers : Array (Nat × Nat) := #[]
  let mut xferIssues : List String := []
  let mut transfers : Std.HashMap Nat (Array Transfer) := {}
  -- Streams, one per (channel, subchannel) that a get reads or a put feeds.
  let slots := (list.flatMap fun ep => ep.feeds.map (ep.chan, ·)).foldl
    (init := ([] : List (String × List Int))) fun acc s => if acc.contains s then acc else acc ++ [s]
  for (chan, slot) in slots do
    let puts := list.filter fun ep => ep.isPut && ep.chan == chan && ep.feeds.contains slot
    let gets := list.filter fun ep => !ep.isPut && ep.chan == chan && ep.slot == slot
    -- Element ranges, in token order (event order, which D33 makes consistent).
    let mut pstart := 0
    let mut pr : List (Endpoint × Nat × Nat) := []
    for ep in puts do
      pr := pr ++ [(ep, pstart, pstart + ep.count)]
      pstart := pstart + ep.count
    let mut gstart := 0
    let mut gr : List (Endpoint × Nat × Nat) := []
    for ep in gets do
      gr := gr ++ [(ep, gstart, gstart + ep.count)]
      gstart := gstart + ep.count
    for (P, ps, pe) in pr do
      for (G, gs, ge) in gr do
        if ps < ge && gs < pe then
          -- They share elements: a transfer between them.
          -- Instances of one `air.launch` may run one after another, so they must not
          -- communicate (D37).
          if let (some (lp, pi), some (lg, gi)) := (ip.ctxs[P.event]!.launchInst, ip.ctxs[G.event]!.launchInst) then
            if lp == lg && pi != gi then
              errors := errors ++ [s!"@{chan}{slot}: event {P.event}'s put feeds event {G.event}'s get across two instances of one air.launch ({pi} and {gi}), which may run one after another (D37)"]
          if P.sync || G.sync then
            preds := preds.modify (2 * G.event + 1) (· ++ [2 * P.event + 1])
          else
            preds := preds.modify (2 * G.event + 1) (· ++ [2 * P.event])
            preds := preds.modify (2 * P.event + 1) (· ++ [2 * G.event])
          -- The transfer event: P's reads of what G receives. It starts after P's predecessors
          -- and is over before G completes (D36(b)) and before P completes.
          let t := n + xfers.size
          xfers := xfers.push (P.event, G.event)
          let pEv := p.events[P.event]!
          raceEdges := raceEdges ++ ((pEv.operandEvents.toList ++ pEv.implicitDeps).map (·, t)) ++
            [(t, G.event), (t, P.event)]
          if P.sync || G.sync then raceEdges := raceEdges ++ [(P.event, G.event)]
          -- D36(a): within the transfer, a location read at stream step i and written at step j
          -- is well defined iff i ≤ j. Only when the put and the get can overlap: if tokens or a
          -- blocking op order the put before the get, every read precedes every write.
          if P.buf == G.buf && !g.reachFast rows P.event G.event then
            let realPos := (G.dst.filter (!·.2)).map (·.1)
            let mut writeStep : Std.HashMap Int Nat := {}
            for q in realPos, k in [0:realPos.length] do
              if !writeStep.contains q then writeStep := writeStep.insert q (gs + k)
            for (q, isPad) in G.dst do
              if isPad && !writeStep.contains q then writeStep := writeStep.insert q gs
            for m in [max ps gs : min pe ge] do
              if let some (some q) := P.stream[m - ps]? then
                if let some j := writeStep[q]? then
                  if m > j then
                    xferIssues := xferIssues ++ [s!"race inside the transfer from event {P.event} to event {G.event} on @{chan}{slot}: {ip.buffers[P.buf]!.name} element {q} is read at stream step {m}, after it may already be written at step {j} (D36(a))"]
                    break
          let mut ts := transfers.getD G.event #[]
          for m in [max ps gs : min pe ge] do
            ts := ts.push { put := P.event, putIdx := m - ps, get := G.event, getIdx := m - gs }
          transfers := transfers.insert G.event ts
    -- Imbalance (D34).
    if pstart > gstart then
      for (P, ps, pe) in pr do
        if pe > gstart then
          if P.sync then
            warnings := warnings ++ [s!"@{chan}{slot}: {pe - max ps gstart} element(s) of event {P.event}'s put are never got (buffered, D30)"]
          else
            preds := preds.modify (2 * P.event + 1) (· ++ [never])
            errors := errors ++ [s!"@{chan}{slot}: event {P.event}'s async put has {pe - max ps gstart} element(s) no get takes: it can never complete (D34)"]
    if gstart > pstart then
      for (G, gs, ge) in gr do
        if ge > pstart then
          preds := preds.modify (2 * G.event + 1) (· ++ [never])
          errors := errors ++ [s!"@{chan}{slot}: event {G.event}'s get waits for {ge - max gs pstart} element(s) no put provides"]
  return { endpoints := eps, errors, warnings, andGraph := ⟨preds⟩, raceEdges, transfers,
           xfers, xferIssues }

/-! ### Deadlock -/

inductive Progress where
  /-- A schedule, checked by `scheduleB` (`scheduleB_sound`). -/
  | completes (schedule : List Nat)
  /-- A stuck set, checked by `stuckB` (`no_schedule_of_stuckB`). -/
  | deadlocks (stuck : List Nat)
  /-- Kahn's answer failed its check: a bug in this file. -/
  | unchecked

def ChanAnalysis.progress (ca : ChanAnalysis) : Progress :=
  let g := ca.andGraph
  -- The never-firing node is not part of a run: drop it when nothing waits for it.
  let neverUsed := (List.range g.size).any fun v => v + 1 != g.size && (g.predsOf v).contains (g.size - 1)
  let g' : DepGraph := if neverUsed then g else ⟨g.preds.pop⟩
  match DepGraph.kahn g' with
  | .inl l => if g'.scheduleB l then .completes l else .unchecked
  | .inr s => if g'.stuckB s && s.all (· < g'.size) then .deadlocks s else .unchecked

/-! ### Races, with channel orderings -/

/-- The event graph with the orderings channels add, renumbered so that it is forward (which the
race checker needs), with the renumbering. `none` if it has a cycle. -/
def IProgram.raceGraph (ip : IProgram) (ca : ChanAnalysis) : Option (DepGraph × Array Nat) := do
  let g := ip.prog.graph
  let n := g.size
  let total := n + ca.xfers.size
  let mut preds : Array (List Nat) := g.preds ++ Array.replicate ca.xfers.size []
  for (u, v) in ca.raceEdges do
    if v < total then preds := preds.modify v (· ++ [u])
  let g2 : DepGraph := ⟨preds⟩
  let .inl order := DepGraph.kahn g2 | none
  -- `pos[v]` is v's new number.
  let mut pos : Array Nat := Array.replicate total 0
  for v in order, i in [0:order.length] do
    pos := pos.set! v i
  let mut renum : Array (List Nat) := Array.replicate total []
  for v in [0:total] do
    renum := renum.set! pos[v]! ((g2.predsOf v).map (pos[·]!))
  let g3 : DepGraph := ⟨renum⟩
  if !g3.forwardB then none
  return (g3, pos)

/-- The footprints channels contribute, for events and transfer events alike (node `≥ n` is
transfer `node - n`):
- a put reads the elements no get receives;
- a transfer reads the elements its get receives;
- a get writes its destination (padding included). -/
def ChanAnalysis.footprint (ca : ChanAnalysis) (n : Nat) (node : Nat) : List Access :=
  if node ≥ n then
    match ca.xfers[node - n]? with
    | none => []
    | some (P, G) =>
      match ca.endpoints[P]? with
      | none => []
      | some ep =>
        let idxs := ((ca.transfers.getD G #[]).filter (·.put == P)).map (·.putIdx)
        [⟨ep.buf, .read, idxs.toList.filterMap fun i => ep.stream[i]?.join⟩]
  else
    match ca.endpoints[node]? with
    | none => []
    | some ep =>
      if ep.isPut then
        let delivered := (ca.transfers.toList.flatMap fun (_, ts) => ts.toList.filter (·.put == node)).map (·.putIdx)
        let rest := ep.stream.zipIdx.filterMap fun (x, i) => if delivered.contains i then none else x
        [⟨ep.buf, .read, rest⟩]
      else [⟨ep.buf, .write, ep.dst.map (·.1)⟩]

/-! ### Running -/

structure CState where
  m : MState := {}
  /-- What each put read, by event and stream index. -/
  sent : Std.HashMap (Nat × Nat) Val := {}

/-- Fire one node: a put reads its source when it starts; a get writes its destination when it
finishes; every other event acts when it finishes. -/
def IProgram.fireNode (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis) (node : Nat)
    (s : CState) : CState := Id.run do
  if s.m.fault.isSome then return s
  let v := node / 2
  let isStart := node % 2 == 0
  let some ev := ip.prog.events[v]? | return s
  match ca.endpoints[v]? with
  | some ep =>
    if ep.isPut && isStart then
      if s.m.freed.contains ep.buf then
        return { s with m := { s.m with fault := some s!"event {v}: a buffer it uses was deallocated" } }
      let zero := zeroOf ip.buffers[ep.buf]!.type
      let mut sent := s.sent
      for x in ep.stream, i in [0:ep.stream.length] do
        sent := sent.insert (v, i) (match x with | some q => s.m.mem[(ep.buf, q)]?.getD .undef | none => zero)
      return { s with sent }
    else if !ep.isPut && !isStart then
      if s.m.freed.contains ep.buf then
        return { s with m := { s.m with fault := some s!"event {v}: a buffer it uses was deallocated" } }
      let zero := zeroOf ip.buffers[ep.buf]!.type
      let ts := ca.transfers.getD v #[]
      let realPos := (ep.dst.filter (!·.2)).map (·.1)
      let mut mem := s.m.mem
      for (q, isPad) in ep.dst do
        if isPad then mem := mem.insert (ep.buf, q) zero
      for t in ts do
        let some x := s.sent[(t.put, t.putIdx)]?
          | return { s with m := { s.m with fault := some s!"event {v}: got an element before it was put" } }
        mem := mem.insert (ep.buf, realPos[t.getIdx]!) x
      return { s with m := { s.m with mem } }
    else return s
  | none =>
    if isStart || ev.kind == .waitAll || ev.kind == .waitAllBlocking then return s
    return { s with m := ip.finish ctx v s.m }

def IProgram.runNodes (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis) (order : List Nat) : MState :=
  (order.foldl (fun s node => ip.fireNode ctx ca node s) { m := ip.initState }).m

end

end Veir.Air
