module

public import Veir.Air.Channels
public import Veir.Air.ChanFast

namespace Veir.Air

@[expose] public section

/-! # From IR to the proven model of channels and DMAs

`Veir.Air.ChanSem` and `Veir.Air.ChanMem` state the semantics and prove the checks. This file builds
their input, a `Chan.Prog`, from a program's events, its channel endpoints
(`IProgram.analyzeChannels`) and its DMAs, and runs the checks. A DMA whose patterns are known is a
stream from the event to itself, element by element, unbuffered: reads may run ahead of writes,
so D20 and D21 follow from the model rather than being checked separately. A DMA whose patterns
are only known when running stays one event (D7, D23).
- deadlock: `Chan.checkH` on the execution `Chan.genTrace` proposes (`checkH_true`,
  `checkH_false`);
- races: `Chan.racesOk` on that execution (`raceFree_of_racesOk`), with the footprints below;
- the outcome: that execution, run on concrete memory. When it is race-free, every execution
  ends the same way (`Chan.outcome_uniqueH`).

**Not proven** (this file is the trusted glue):
- that the elements built here are those D28–D34 and D51 describe for the IR;
- that the concrete effects (`IProgram.finish`, the copies below) are framed by the footprints
  (`Chan.LFramed`).

Not covered yet, and refused:
- puts on one subchannel that tokens do not order, as packet fan-in has;
- a slot fed both by a broadcast put and by other puts;
- an element from an async put to sync and async gets at once (D51 decides one get only).
-/

structure ChanModel where
  prog : Chan.Prog
  /-- Per element: its put event and the index in that put's stream. -/
  srcOf : Array (Option (Nat × Nat))
  /-- Per element, per slot: its get event there and the index among that get's received
  positions. -/
  dstOf : Array (List (Option (Nat × Nat)))
  /-- Per element: its stream's slots, for messages. -/
  slotName : Array String
  /-- Per element: its position in its stream. -/
  pos : Array Nat
  /-- Per element: the location it is read from (`none`: a padded zero), and the buffer it comes
  from (for the zero's type). -/
  srcLoc : Array (Option (Nat × Int)) := #[]
  srcBuf : Array Nat := #[]
  /-- Per element, per slot: the location it is written to. -/
  dstLoc : Array (List (Option (Nat × Int))) := #[]
  /-- DMAs whose transfer is modelled element by element (`IProgram.staticDma`). -/
  dmaEvents : Std.HashSet Nat := {}

def IProgram.chanModel (ip : IProgram) (ca : ChanAnalysis) : Except String ChanModel := do
  let p := ip.prog
  let g := p.graph
  let rows := g.reachRows
  let n := p.events.size
  let list := (List.range n).filterMap fun v => ca.endpoints[v]?
  -- Streams: the slots a put feeds together (one, or a broadcast's), and slots only gets read.
  let mut streams : List (String × List (List Int)) := []
  for ep in list do
    if ep.isPut then
      if !streams.contains (ep.chan, ep.feeds) then streams := streams ++ [(ep.chan, ep.feeds)]
  for ep in list do
    if !ep.isPut && !(streams.any fun (c, fs) => c == ep.chan && fs.contains ep.slot) then
      streams := streams ++ [(ep.chan, [ep.slot])]
  -- A slot belongs to one stream: no put feeds it together with other slots and another alone.
  for (c, fs) in streams do
    for (c', fs') in streams do
      if c == c' && fs != fs' && fs.any fs'.contains then
        throw s!"@{c}: slot(s) fed both as {fs} and as {fs'}; mixing broadcast and other puts on one slot is not in the proven channel model yet"
  let mut elems : Array Chan.Elem := #[]
  let mut srcOf : Array (Option (Nat × Nat)) := #[]
  let mut dstOf : Array (List (Option (Nat × Nat))) := #[]
  let mut slotName : Array String := #[]
  let mut pos : Array Nat := #[]
  let mut srcLoc : Array (Option (Nat × Int)) := #[]
  let mut srcBuf : Array Nat := #[]
  let mut dstLoc : Array (List (Option (Nat × Int))) := #[]
  for (chan, slots) in streams do
    let puts := list.filter fun ep => ep.isPut && ep.chan == chan && ep.feeds == slots
    let name := if slots.length == 1 then s!"@{chan}{slots.head!}" else s!"@{chan} broadcast to {slots}"
    -- The stream's order is the token order (D33, D34); it must be total.
    for (a, b) in puts.zip puts.tail do
      if !g.reachFast rows a.event b.event then
        throw s!"{name}: puts of events {a.event} and {b.event} feed it with no token path between them; their order in the stream is not defined (D33; packet fan-in is not in the proven channel model yet)"
    let mut pr : List (Endpoint × Nat) := []
    let mut ps := 0
    for ep in puts do
      pr := pr ++ [(ep, ps)]
      ps := ps + ep.count
    let mut grs : List (List (Endpoint × Nat) × Nat) := []
    for slot in slots do
      let gets := list.filter fun ep => !ep.isPut && ep.chan == chan && ep.slot == slot
      for (a, b) in gets.zip gets.tail do
        if !g.reachFast rows a.event b.event then
          throw s!"@{chan}{slot}: gets of events {a.event} and {b.event} read it with no token path between them (D33)"
      let mut gr : List (Endpoint × Nat) := []
      let mut gs := 0
      for ep in gets do
        gr := gr ++ [(ep, gs)]
        gs := gs + ep.count
      grs := grs ++ [(gr, gs)]
    let total := grs.foldl (fun acc (_, gs) => max acc gs) ps
    let first := elems.size
    for m in [0:total] do
      let src := pr.find? fun (ep, s) => s ≤ m && m < s + ep.count
      let dsts : List (Option (Endpoint × Nat)) :=
        grs.map fun (gr, _) => gr.find? fun ((ep : Endpoint), s) => s ≤ m && m < s + ep.count
      -- D51: buffered iff an end is sync. With several gets, a sync put decides; with an async
      -- put, the gets must agree.
      let srcSync := (src.map (·.1.sync)).getD false
      let present := dsts.filterMap fun d => d.map fun ((ep : Endpoint), _) => ep.sync
      let buffered ←
        if srcSync then pure true
        else if present.all id && !present.isEmpty then pure true
        else if present.all (!·) then pure false
        else throw s!"{name}: element {m} goes from an async put to sync and async gets at once; whether it is buffered is not decided (D51 covers one get)"
      let prev := if m == 0 then none else some (first + m - 1)
      elems := elems.push ⟨src.map (·.1.event), dsts.map fun d => d.map fun ((ep : Endpoint), _) => ep.event, prev, buffered⟩
      srcOf := srcOf.push (src.map fun (ep, s) => (ep.event, m - s))
      dstOf := dstOf.push (dsts.map fun d => d.map fun ((ep : Endpoint), s) => (ep.event, m - s))
      slotName := slotName.push name
      pos := pos.push m
      srcLoc := srcLoc.push (src.bind fun (ep, s) => (ep.stream[m - s]?).join.map (ep.buf, ·))
      srcBuf := srcBuf.push ((src.map (·.1.buf)).getD 0)
      dstLoc := dstLoc.push (dsts.map fun d => d.bind fun ((ep : Endpoint), s) =>
        ((ep.dst.filter (!·.2)).map (·.1))[m - s]?.map (ep.buf, ·))
  -- DMAs with known patterns: a stream from the event to itself, unbuffered (D20, D21).
  let mut dmaEvents : Std.HashSet Nat := {}
  for v in [0:n] do
    let some (sb, stream, db, dpos) := ip.staticDma v | continue
    dmaEvents := dmaEvents.insert v
    let first := elems.size
    for x in stream, q in dpos, m in [0:dpos.length] do
      elems := elems.push ⟨some v, [some v], if m == 0 then none else some (first + m - 1), false⟩
      srcOf := srcOf.push none
      dstOf := dstOf.push [none]
      slotName := slotName.push s!"event {v}{pathStr ip.ctxs[v]!.path} (air.dma_memcpy_nd)"
      pos := pos.push m
      srcLoc := srcLoc.push (x.map (sb, ·))
      srcBuf := srcBuf.push sb
      dstLoc := dstLoc.push [some (db, q)]
  return { prog := ⟨g, elems⟩, srcOf, dstOf, slotName, pos, srcLoc, srcBuf, dstLoc, dmaEvents }

/-- A fresh buffer number for the values in flight. -/
def IProgram.slotBuf (ip : IProgram) : Nat := ip.buffers.size

/-- A fresh buffer number for event results: location `(resultBuf, u)` holds event `u`'s results. -/
def IProgram.resultBuf (ip : IProgram) : Nat := ip.buffers.size + 1

/-- The events whose results event `v` reads when it finishes: those its body uses (D4), and, for
a DMA, those its buffers or pattern come from. -/
def IProgram.resultReads (ip : IProgram) (v : Nat) : List Nat := Id.run do
  let some e := ip.prog.events[v]? | return []
  let mut out := e.dataDeps
  if let (some info, some c) := (ip.dmas[v]?, ip.ctxs[v]?) then
    let vps := [info.src.memref, info.dst.memref] ++
      ([info.src.offsets, info.src.sizes, info.src.strides, info.dst.offsets, info.dst.sizes,
        info.dst.strides].flatMap fun xs => xs.toList.filterMap fun | .inr vp => some vp | .inl _ => none)
    for vp in vps do
      if let some (.result u _) := c.env[vp]? then
        if !out.contains u then out := out ++ [u]
  return out

/-- Where element `k` lands at slot `i`. -/
def ChanModel.dstAt (cm : ChanModel) (k i : Nat) : Option (Nat × Int) :=
  (cm.dstLoc[k]? >>= (·[i]?)).join

/-- What each label reads and writes (`Chan.MemSpec.fp` on this program). -/
def IProgram.labelFp (ip : IProgram) (ca : ChanAnalysis) (cm : ChanModel)
    (fps0 : Array (List Access)) : Chan.LFp
  | .start _ => []
  | .finish v =>
    -- Results are memory too: written when the event finishes, read by the events using them.
    let results : List Access :=
      ⟨ip.resultBuf, .write, [Int.ofNat v]⟩ :: (ip.resultReads v).map fun u => ⟨ip.resultBuf, .read, [Int.ofNat u]⟩
    results ++
    if cm.dmaEvents.contains v then [] else
    match ca.endpoints[v]? with
    | some ep => if ep.isPut then [] else [⟨ep.buf, .write, (ep.dst.filter (·.2)).map (·.1)⟩]
    | none => fps0[v]?.getD []
  | .read k =>
    let slotW : Access := ⟨ip.slotBuf, .write, [k]⟩
    match (cm.srcLoc[k]?).join with
    | some (b, q) => [slotW, ⟨b, .read, [q]⟩]
    | none => [slotW]
  | .push _ => []
  | .pull k i =>
    let slotR : Access := ⟨ip.slotBuf, .read, [k]⟩
    match cm.dstAt k i with
    | some (b, q) => [slotR, ⟨b, .write, [q]⟩]
    | none => [slotR]
  | .xfer k =>
    let slotR : Access := ⟨ip.slotBuf, .read, [k]⟩
    slotR :: ((List.range ((cm.dstLoc[k]?.map (·.length)).getD 0)).filterMap fun i =>
      (cm.dstAt k i).map fun (b, q) => ⟨b, .write, [q]⟩)

structure LState where
  m : MState
  slots : Std.HashMap Nat Val := {}

/-- One label on concrete memory (`Chan.MemSpec.eff` on this program). -/
def IProgram.fireLabel (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis)
    (cm : ChanModel) (s : LState) (l : Chan.Label) : LState := Id.run do
  if s.m.fault.isSome then return s
  let freed (who : String) : LState :=
    { s with m := { s.m with fault := some s!"{who}: a buffer it uses was deallocated" } }
  match l with
  | .start _ | .push _ => return s
  | .finish v =>
    if cm.dmaEvents.contains v then return s
    match ca.endpoints[v]? with
    | some ep =>
      if ep.isPut then return s
      if s.m.freed.contains ep.buf then return freed s!"event {v}"
      let zero := zeroOf ip.buffers[ep.buf]!.type
      let mut mem := s.m.mem
      for (q, isPad) in ep.dst do
        if isPad then mem := mem.insert (ep.buf, q) zero
      return { s with m := { s.m with mem } }
    | none => return { s with m := ip.finish ctx v s.m }
  | .read k =>
    let b := cm.srcBuf[k]!
    if s.m.freed.contains b then return freed s!"the read of element {k}"
    let x := match (cm.srcLoc[k]?).join with
      | some q => s.m.mem[q]?.getD .undef
      | none => zeroOf ip.buffers[b]!.type
    return { s with slots := s.slots.insert k x }
  | .pull k i =>
    let some (b, q) := cm.dstAt k i | return s
    if s.m.freed.contains b then return freed s!"element {k}'s write"
    return { s with m := { s.m with mem := s.m.mem.insert (b, q) (s.slots[k]?.getD .undef) } }
  | .xfer k =>
    let n := (cm.dstLoc[k]?.map (·.length)).getD 0
    let mut mem := s.m.mem
    for i in [0:n] do
      let some (b, q) := cm.dstAt k i | continue
      if s.m.freed.contains b then return freed s!"element {k}'s write"
      mem := mem.insert (b, q) (s.slots[k]?.getD .undef)
    return { s with m := { s.m with mem } }

/-- The checked verdicts: an execution, whether it completes (`none`: internal error), whether it
is race-free (`Chan.racesOk`), and witnesses of races for messages. -/
structure ChanVerdict where
  trace : List Chan.Label
  completes : Option Bool
  raceFree : Bool
  witnesses : List (Nat × Nat)
  /-- For the first race: an execution, checked by `Chan.checkH`, firing its two labels the other
  way round. -/
  alt : Option (Chan.Label × Chan.Label × List Chan.Label) := none

def ChanModel.verdict (cm : ChanModel) (fp : Chan.LFp) (checkRaces := true) : ChanVerdict :=
  let cp := cm.prog
  let idx := Chan.buildIndex cp
  let t := Chan.genTrace cp idx
  let c := Chan.checkH cp idx t
  if c == some true && checkRaces then
    let g := Chan.posGraphH cp idx t (Chan.positions t)
    let ok := Chan.racesOk g fp t
    let ws := if ok then [] else Chan.raceWitnesses g fp t
    let arr := t.toArray
    let alt := ws.head?.bind fun (i, j) =>
      let (x, y) := (arr[i]!, arr[j]!)
      (Chan.altTrace cp idx x y).map (x, y, ·)
    { trace := t, completes := c, raceFree := ok, witnesses := ws, alt }
  else { trace := t, completes := c, raceFree := true, witnesses := [] }

def IProgram.runLabels (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis)
    (cm : ChanModel) (t : List Chan.Label) : MState :=
  (t.foldl (ip.fireLabel ctx ca cm) { m := ip.initState }).m

/-- The event a label belongs to, for grouping messages. -/
def ChanModel.owner (cm : ChanModel) : Chan.Label → Nat
  | .start v | .finish v => v
  | .read k | .push k => ((cm.prog.elems[k]?).bind (·.src)).getD 0
  | .pull k i => ((cm.prog.elems[k]?).bind fun e => e.dsts[i]?.join).getD 0
  | .xfer k => ((cm.prog.elems[k]?).bind fun e => e.dsts.head?.join).getD 0

/-- A label, for messages. -/
def ChanModel.labelName (cm : ChanModel) (eventAt : Nat → String) : Chan.Label → String
  | .start v => s!"start of {eventAt v}"
  | .finish v => s!"finish of {eventAt v}"
  | .read k => s!"the read of element {cm.pos[k]!} of {cm.slotName[k]!}"
  | .push k => s!"element {cm.pos[k]!} of {cm.slotName[k]!} entering the buffer"
  | .pull k i => s!"element {cm.pos[k]!} of {cm.slotName[k]!} leaving the buffer at slot {i}"
  | .xfer k => s!"the transfer of element {cm.pos[k]!} of {cm.slotName[k]!}"

end

end Veir.Air
