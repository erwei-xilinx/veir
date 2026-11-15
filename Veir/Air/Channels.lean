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
deriving Inhabited

def Endpoint.count (e : Endpoint) : Nat :=
  if e.isPut then e.stream.length else (e.dst.filter (!·.2)).length

structure ChanAnalysis where
  endpoints : Std.HashMap Nat Endpoint
  /-- D33 and D37 violations. -/
  errors : List String

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
  -- D33: one subchannel, one direction: totally ordered by tokens.
  let list := (List.range n).filterMap fun v => eps[v]?
  for a in list do
    for b in list do
      if a.event < b.event && a.chan == b.chan && a.isPut == b.isPut && a.slot == b.slot &&
          !g.reachFast rows a.event b.event then
        errors := errors ++ [s!"channel order race (D33): two {if a.isPut then "puts" else "gets"} on @{a.chan}{a.slot} (events {a.event} and {b.event}) with no token path between them"]
  -- D37: instances of one `air.launch` may run one after another, so they must not communicate.
  for P in list do
    for G in list do
      if P.isPut && !G.isPut && P.chan == G.chan && P.feeds.contains G.slot then
        if let (some (lp, pi), some (lg, gi)) := (ip.ctxs[P.event]!.launchInst, ip.ctxs[G.event]!.launchInst) then
          if lp == lg && pi != gi then
            errors := errors ++ [s!"@{G.chan}{G.slot}: event {P.event}'s put feeds event {G.event}'s get across two instances of one air.launch ({pi} and {gi}), which may run one after another (D37)"]
  return { endpoints := eps, errors }

end

end Veir.Air
