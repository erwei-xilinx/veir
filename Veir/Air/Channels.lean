module

public import Veir.Air.Instance

namespace Veir.Air

@[expose] public section

/-! # Layer 4: channel endpoints, from IR

What each channel op moves, computed from IR (trusted glue, not proven):
- a subchannel (a channel and its indices) is an ordered stream of elements (D28, D34);
- a put's stream, with padding zeros (D31, D20); a get's destination positions, with the padded
  ones marked (D31);
- the subchannels a put feeds: its own, every destination of a broadcast, or the one `dest`
  selects (D29).

Two rules are checked here: endpoints on one subchannel in one direction are ordered by tokens
(D33), and instances of one `air.launch` do not communicate (D37).

Everything else -- deadlock, races, the outcome -- is decided on the proven channel model
(`Veir.Air.ChanSem`, `ChanMem`, `ChanFast`), built from these endpoints by `Veir.Air.ChanGlue`.
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
  /-- D54: the `air.channel.issue` whose run-time offset (in elements) is added to every position
  when it runs; `none` if the positions are those above. -/
  shiftBy : Option Nat := none
  /-- D56: the `air.launch` instance it belongs to; each has its own streams. -/
  inst : Option (Nat × List Int) := none
  /-- D23: offsets computed by events, read when the transfer runs: each value times its stride
  is added to every position. -/
  dynShift : List (HVal × Int) := []
deriving Inhabited

def Endpoint.count (e : Endpoint) : Nat :=
  if e.isPut then e.stream.length else (e.dst.filter (!·.2)).length

structure ChanAnalysis where
  endpoints : Std.HashMap Nat Endpoint
  /-- D33 and D37 violations. -/
  errors : List String
  /-- D54: the `air.channel.issue` that starts each transfer tagged `air.device_issue`. -/
  issueOf : Std.HashMap Nat Nat := {}

/-- The endpoint of a channel event, from what is known before running. -/
def IProgram.endpoint (ip : IProgram) (v : Nat) (issue : Option Nat := none) :
    Except String (Option Endpoint) := do
  let some info := ip.chans[v]? | return none
  let c := ip.ctxs[v]!
  let e := ip.prog.events[v]!
  let what := s!"event {v}{pathStr c.path} (@{info.chan})"
  let some decl := ip.chanDecls[info.chan]? | throw s!"{what}: undeclared channel"
  let bufOfH (h : HVal) : Option Nat := match h with
    | .val (.buf b) => some b
    | .result e i => ip.resultBufs[(e, i)]?
    | _ => none
  -- A whole view: its elements, where they lie in the buffer (`IProgram.viewPos`).
  let viewP : Option (Nat × Array Int) := match c.env[info.side.memref]? with
    | some (.result e i) => ip.viewPos[(e, i)]?
    | _ => none
  if let some (vb, P) := viewP then
    if issue.isSome then throw s!"{what}: an air.channel.issue on a view is not supported"
    let sync := e.kind == .putBlocking || e.kind == .getBlocking
    if info.isPut then
      return some { event := v, isPut := true, sync, chan := info.chan, slot := info.indices,
                    feeds := ← feedSlots decl info.indices info.dest, stream := P.toList.map some,
                    buf := vb, inst := c.launchInst }
    else
      return some { event := v, isPut := false, sync, chan := info.chan, slot := info.indices,
                    feeds := [info.indices], dst := P.toList.map (·, false), buf := vb,
                    inst := c.launchInst }
  let some buf := c.env[info.side.memref]? >>= bufOfH | throw s!"{what}: unknown buffer"
  let t := ip.buffers[buf]!.type
  let entries (xs : Array (Int ⊕ ValuePtr)) : Except String (Array Int) :=
    match xs.mapM fun | .inl n => some n | .inr vp => (c.env[vp]? >>= fun | .val x => x.toInt? | _ => none) with
    | some a => pure a
    | none => throw s!"{what}: a channel transfer's pattern must be known before running"
  -- D23: an offset an event computes is read when the transfer runs; it is 0 here, and shifts every
  -- position by its value times its dimension's stride. Sizes and strides must be known.
  let strides0 ← entries info.side.strides
  let mut dynShift : List (HVal × Int) := []
  let mut offs : Array Int := #[]
  for o in info.side.offsets, d in [0:info.side.offsets.size] do
    match o with
    | .inl n => offs := offs.push n
    | .inr vp =>
      match c.env[vp]? with
      | some (.val x) =>
        match x.toInt? with
        | some n => offs := offs.push n
        | none => throw s!"{what}: a channel transfer's pattern must be known before running"
      | some h@(.result _ _) =>
        offs := offs.push 0
        dynShift := dynShift ++ [(h, strides0[d]!)]
      | _ => throw s!"{what}: a channel transfer's pattern must be known before running"
  -- D54: the issue gives the outermost length, or an offset in elements added to every position:
  -- known before running (host values), or read when the issue runs.
  let mut sizes ← entries info.side.sizes
  let mut shift : Int := 0
  let mut shiftBy : Option Nat := none
  if let some i := issue then
    let some ii := ip.issues[i]? | throw s!"{what}: internal error: no issue {i}"
    let ic := ip.ctxs[i]!
    if let some lv := ii.length then
      match ic.env[lv]? with
      | some (.val x) =>
        match x.toInt? with
        | some n => if sizes.size > 0 then sizes := sizes.set! 0 n
        | none => throw s!"{what}: the length air.channel.issue gives is not known before running (pass --args)"
      | _ => throw s!"{what}: a length computed by an event is not supported (D54: a host issue gives a launch value)"
    if let some ov := ii.offset then
      match ic.env[ov]? with
      | some (.val x) =>
        match x.toInt? with
        | some n => shift := n
        | none => throw s!"{what}: the offset air.channel.issue gives is not known (pass --args)"
      | some (.result _ _) => shiftBy := some i
      | _ => throw s!"{what}: the offset air.channel.issue gives is not a value"
  let dims ← sidePositions t offs sizes strides0
  let sync := e.kind == .putBlocking || e.kind == .getBlocking
  if info.isPut then
    let stream := (← srcStream dims info.padBefore info.padAfter).map (·.map (· + shift))
    if shiftBy.isNone && dynShift.isEmpty then checkBounds t ip.buffers[buf]!.name (stream.filterMap id)
    return some { event := v, isPut := true, sync, chan := info.chan, slot := info.indices,
                  feeds := ← feedSlots decl info.indices info.dest, stream, buf, shiftBy,
                  inst := c.launchInst, dynShift }
  else
    let dst0 :=
      if info.padBefore.isEmpty then (positions dims).map (·, false)
      else paddedDst 0 (dims.zip ((info.padBefore.toList.map Int.toNat).zip (info.padAfter.toList.map Int.toNat)))
    let dst := dst0.map fun (q, pad) => (q + shift, pad)
    if !info.padBefore.isEmpty && info.padBefore.size != dims.length then
      throw s!"{what}: padding rank differs from the pattern's"
    if shiftBy.isNone && dynShift.isEmpty then checkBounds t ip.buffers[buf]!.name (dst.map (·.1))
    return some { event := v, isPut := false, sync, chan := info.chan, slot := info.indices,
                  feeds := [info.indices], dst, buf, shiftBy, inst := c.launchInst, dynShift }

def IProgram.analyzeChannels (ip : IProgram) : Except String ChanAnalysis := do
  let p := ip.prog
  let g := p.graph
  let rows := g.reachRows
  let n := p.events.size
  -- D54: pair each tagged transfer with the issue of its `issue_id`, in order, within one launch
  -- instance; any other count is an error.
  let mut issueOf : Std.HashMap Nat Nat := {}
  let mut keys : List (Nat × Option (Nat × List Int)) := []
  for v in [0:n] do
    if let some id := (ip.chans[v]?).bind (·.issueId) then
      let k := (id, ip.ctxs[v]!.launchInst)
      if !keys.contains k then keys := keys ++ [k]
    if let some ii := ip.issues[v]? then
      let k := (ii.issueId, ip.ctxs[v]!.launchInst)
      if !keys.contains k then keys := keys ++ [k]
  for (id, li) in keys do
    let tagged := (List.range n).filter fun v =>
      ((ip.chans[v]?).bind (·.issueId)) == some id && ip.ctxs[v]!.launchInst == li
    let issues := (List.range n).filter fun v =>
      ((ip.issues[v]?).map (·.issueId)) == some id && ip.ctxs[v]!.launchInst == li
    if tagged.length != issues.length then
      throw s!"issue_id {id}: {issues.length} air.channel.issue(s) for {tagged.length} transfer(s) tagged air.device_issue in one launch instance (D54)"
    for t in tagged, i in issues do
      issueOf := issueOf.insert t i
  let mut eps : Std.HashMap Nat Endpoint := {}
  for v in [0:n] do
    if let some ep ← ip.endpoint v issueOf[v]? then eps := eps.insert v ep
  let mut errors : List String := []
  -- D33: one subchannel, one direction, one launch instance (D56): totally ordered by tokens.
  let list := (List.range n).filterMap fun v => eps[v]?
  for a in list do
    for b in list do
      if a.event < b.event && a.chan == b.chan && a.isPut == b.isPut && a.slot == b.slot &&
          a.inst == b.inst && !g.reachFast rows a.event b.event then
        errors := errors ++ [s!"channel order race (D33): two {if a.isPut then "puts" else "gets"} on @{a.chan}{a.slot} (events {a.event} and {b.event}) with no token path between them"]
  -- D37, D56: each launch instance has its own streams, so instances cannot communicate. A put
  -- whose slot only another instance gets from is an attempt to.
  for P in list do
    if !P.isPut then continue
    for slot in P.feeds do
      let mine := list.any fun G => !G.isPut && G.chan == P.chan && G.slot == slot && G.inst == P.inst
      if mine then continue
      if let some G := list.find? fun G => !G.isPut && G.chan == P.chan && G.slot == slot && G.inst != P.inst then
        if let (some (_, pi), some (_, gi)) := (P.inst, G.inst) then
          errors := errors ++ [s!"@{G.chan}{G.slot}: event {P.event}'s put in air.launch instance {pi} feeds a slot only instance {gi} gets from (event {G.event}); each instance has its own streams and instances do not communicate (D37, D56)"]
  return { endpoints := eps, errors, issueOf }

end

end Veir.Air
