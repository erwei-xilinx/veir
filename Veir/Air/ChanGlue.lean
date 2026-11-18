module

public import Veir.Air.Channels
public import Veir.Air.ChanEventReach

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
- races: `Chan.racesOkE` on that execution (`raceFree_of_racesOkE`), with the footprints below;
- the outcome: that execution, run on concrete memory. When it is race-free, every execution
  ends the same way (`Chan.outcome_uniqueH`).

**Not proven** (this file is the trusted glue):
- that the elements built here are those D28–D34 and D51 describe for the IR;
- that the concrete effects (`IProgram.finish`, the copies below) are framed by the footprints
  (`Chan.LFramed`).

Puts from different subchannels feeding one stream with no token order (packet fan-in) arrive
whole in any order (D52): `putOrders` lists the orders, and each gives its own model; the
program's executions are those of all of them.

Not covered yet, and refused: a slot fed both by a broadcast put and by other puts.
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
  /-- D54: per element, the issue whose run-time offset shifts its source; per slot, its
  destination. -/
  srcShift : Array (Option Nat) := #[]
  dstShift : Array (List (Option Nat)) := #[]
  /-- D23: per element, offsets computed by events that shift its source; per slot, its
  destination. -/
  srcDyn : Array (List (HVal × Int)) := #[]
  dstDyn : Array (List (List (HVal × Int))) := #[]

/-- The streams of a program: the slots a put feeds together (one, or a broadcast's), and slots
only gets read. -/
abbrev StreamKey := String × List (List Int) × Option (Nat × List Int)

def streamsOf (list : List Endpoint) : List StreamKey := Id.run do
  let mut streams : List StreamKey := []
  for ep in list do
    if ep.isPut then
      if !streams.contains (ep.chan, ep.feeds, ep.inst) then streams := streams ++ [(ep.chan, ep.feeds, ep.inst)]
  for ep in list do
    if !ep.isPut && !(streams.any fun (c, fs, i) => c == ep.chan && fs.contains ep.slot && i == ep.inst) then
      streams := streams ++ [(ep.chan, [ep.slot], ep.inst)]
  return streams

/-- The orders of `xs` in which every `a` with `before a b` comes before `b`, at most `limit`. -/
partial def linearOrders (xs : List Nat) (before : Nat → Nat → Bool) (limit : Nat) : List (List Nat) :=
  match xs with
  | [] => [[]]
  | _ => Id.run do
    let mut out : List (List Nat) := []
    for x in xs do
      if xs.any fun y => y != x && before y x then continue
      for rest in linearOrders (xs.erase x) before limit do
        if out.length ≥ limit then return out
        out := out ++ [x :: rest]
    return out

/-- D52: puts from different subchannels feeding one stream with no token order between them
arrive whole, in any order. Every order the tokens allow, per stream (events of its puts). -/
def IProgram.putOrders (ip : IProgram) (ca : ChanAnalysis) (limit : Nat := 64) :
    Except String (List (List (StreamKey × List Nat))) := do
  let g := ip.prog.graph
  let rows := g.reachRows
  let list := (List.range ip.prog.events.size).filterMap fun v => ca.endpoints[v]?
  let mut choices : List (List (StreamKey × List Nat)) := [[]]
  for (chan, slots, inst) in streamsOf list do
    let puts := list.filter fun ep => ep.isPut && ep.chan == chan && ep.feeds == slots && ep.inst == inst
    -- Puts on one subchannel must be ordered by tokens (D33); only different subchannels may race.
    for a in puts do
      for b in puts do
        if a.event < b.event && a.slot == b.slot && !g.reachFast rows a.event b.event then
          throw s!"@{chan}{a.slot}: puts of events {a.event} and {b.event} on one subchannel with no token path between them (D33)"
    let orders := linearOrders (puts.map (·.event)) (fun a b => g.reachFast rows a b) (limit + 1)
    if orders.length > limit then
      throw s!"@{chan} {slots}: more than {limit} orders of the puts feeding it (D52); too many to check one by one"
    choices := choices.flatMap fun c => orders.map fun o => c ++ [((chan, slots, inst), o)]
    if choices.length > limit then
      throw s!"more than {limit} orders of puts across the program's streams (D52); too many to check one by one"
  return choices

/-- The ends of one stream, in stream order: each end, the stream position of its first element,
and its elements. From cursor `c`, the first end whose run reaches past position `m`. Ends cover
consecutive runs, so for increasing `m` the cursor only moves forward. -/
def endCursor {α : Type} (ends : Array (Endpoint × Nat × Array α)) (c m : Nat) : Nat := Id.run do
  let mut c := c
  while h : c < ends.size do
    let (_, s, a) := ends[c]
    if m < s + a.size then break
    c := c + 1
  return c

/-- The end at cursor `c`, if it covers position `m`: the end `find?` on `s ≤ m < s + count` gives. -/
def endAt? {α : Type} (ends : Array (Endpoint × Nat × Array α)) (c m : Nat) :
    Option (Endpoint × Nat × Array α) :=
  match ends[c]? with
  | some e@(_, s, _) => if s ≤ m then some e else none
  | none => none

def IProgram.chanModel (ip : IProgram) (ca : ChanAnalysis)
    (putOrder : List (StreamKey × List Nat) := []) : Except String ChanModel := do
  let p := ip.prog
  let g := p.graph
  let rows := g.reachRows
  let n := p.events.size
  let list := (List.range n).filterMap fun v => ca.endpoints[v]?
  let streams := streamsOf list
  -- A slot belongs to one stream: no put feeds it together with other slots and another alone.
  for (c, fs, i) in streams do
    for (c', fs', i') in streams do
      if c == c' && i == i' && fs != fs' && fs.any fs'.contains then
        throw s!"@{c}: slot(s) fed both as {fs} and as {fs'}; mixing broadcast and other puts on one slot is not in the proven channel model yet"
  let mut elems : Array Chan.Elem := #[]
  let mut srcOf : Array (Option (Nat × Nat)) := #[]
  let mut dstOf : Array (List (Option (Nat × Nat))) := #[]
  let mut slotName : Array String := #[]
  let mut pos : Array Nat := #[]
  let mut srcLoc : Array (Option (Nat × Int)) := #[]
  let mut srcBuf : Array Nat := #[]
  let mut dstLoc : Array (List (Option (Nat × Int))) := #[]
  let mut srcShift : Array (Option Nat) := #[]
  let mut dstShift : Array (List (Option Nat)) := #[]
  let mut srcDyn : Array (List (HVal × Int)) := #[]
  let mut dstDyn : Array (List (List (HVal × Int))) := #[]
  for (chan, slots, inst) in streams do
    let puts0 := list.filter fun ep => ep.isPut && ep.chan == chan && ep.feeds == slots && ep.inst == inst
    let name := if slots.length == 1 then s!"@{chan}{slots.head!}" else s!"@{chan} broadcast to {slots}"
    -- The stream's order: the token order (D33, D34), or the order chosen for puts the tokens
    -- leave unordered (D52, `putOrders`).
    let puts := match putOrder.lookup (chan, slots, inst) with
      | some evs => evs.filterMap fun v => puts0.find? fun (ep : Endpoint) => ep.event == v
      | none => puts0
    for (a, b) in puts.zip puts.tail do
      if !g.reachFast rows a.event b.event && (putOrder.lookup (chan, slots, inst)).isNone then
        throw s!"{name}: puts of events {a.event} and {b.event} feed it with no token path between them; choose an order (D52, putOrders)"
    -- Each end's elements as an array, its first position in the stream, and its count, once:
    -- the element loop below then walks them with a cursor instead of searching.
    let mut pr : Array (Endpoint × Nat × Array (Option Int)) := #[]
    let mut ps := 0
    for ep in puts do
      let arr := ep.stream.toArray
      pr := pr.push (ep, ps, arr)
      ps := ps + arr.size
    let mut grs : Array (Array (Endpoint × Nat × Array Int) × Nat) := #[]
    for slot in slots do
      let gets := list.filter fun ep => !ep.isPut && ep.chan == chan && ep.slot == slot && ep.inst == inst
      for (a, b) in gets.zip gets.tail do
        if !g.reachFast rows a.event b.event then
          throw s!"@{chan}{slot}: gets of events {a.event} and {b.event} read it with no token path between them (D33)"
      let mut gr : Array (Endpoint × Nat × Array Int) := #[]
      let mut gs := 0
      for ep in gets do
        let arr := ((ep.dst.filter (!·.2)).map (·.1)).toArray
        gr := gr.push (ep, gs, arr)
        gs := gs + arr.size
      grs := grs.push (gr, gs)
    let total := grs.foldl (fun acc (_, gs) => max acc gs) ps
    let first := elems.size
    let mut pc := 0
    let mut gcs : Array Nat := grs.map fun _ => 0
    for m in [0:total] do
      pc := endCursor pr pc m
      let src := endAt? pr pc m
      let mut dsts : List (Option (Endpoint × Nat × Array Int)) := []
      for j in [0:grs.size] do
        let gr := grs[j]!.1
        let c := endCursor gr gcs[j]! m
        gcs := gcs.set! j c
        dsts := dsts ++ [endAt? gr c m]
      -- D51: point to point, buffered iff an end is sync. D53: a broadcast is buffered iff its
      -- put is sync; from an async put it meets every get at once, as the hardware does.
      let srcSync := (src.map (·.1.sync)).getD false
      let dstSync := dsts.any fun d => (d.map fun (ep, _, _) => ep.sync).getD false
      let buffered := if slots.length > 1 then srcSync else srcSync || dstSync
      let prev := if m == 0 then none else some (first + m - 1)
      elems := elems.push ⟨src.map (·.1.event), dsts.map fun d => d.map fun (ep, _, _) => ep.event, prev, buffered⟩
      srcOf := srcOf.push (src.map fun (ep, s, _) => (ep.event, m - s))
      dstOf := dstOf.push (dsts.map fun d => d.map fun (ep, s, _) => (ep.event, m - s))
      slotName := slotName.push name
      pos := pos.push m
      srcLoc := srcLoc.push (src.bind fun (ep, s, a) => (a[m - s]?).join.map (ep.buf, ·))
      srcBuf := srcBuf.push ((src.map (·.1.buf)).getD 0)
      dstLoc := dstLoc.push (dsts.map fun d => d.bind fun (ep, s, a) => a[m - s]?.map (ep.buf, ·))
      srcShift := srcShift.push (src.bind (·.1.shiftBy))
      dstShift := dstShift.push (dsts.map fun d => d.bind fun (ep, _, _) => ep.shiftBy)
      srcDyn := srcDyn.push ((src.map (·.1.dynShift)).getD [])
      dstDyn := dstDyn.push (dsts.map fun d => (d.map fun (ep, _, _) => ep.dynShift).getD [])
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
      srcShift := srcShift.push none
      dstShift := dstShift.push [none]
      srcDyn := srcDyn.push []
      dstDyn := dstDyn.push [[]]
  -- D54: a transfer an issue starts begins after the issue has run.
  let g' : DepGraph := ⟨g.preds.mapIdx fun v ps =>
    match ca.issueOf[v]? with
    | some i => ps ++ [i]
    | none => ps⟩
  return { prog := ⟨g', elems⟩, srcOf, dstOf, slotName, pos, srcLoc, srcBuf, dstLoc, dmaEvents,
           srcShift, dstShift, srcDyn, dstDyn }

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

/-- The issue whose run-time offset shifts element `k`'s destination at slot `i` (D54). -/
def ChanModel.dstShiftAt (cm : ChanModel) (k i : Nat) : Option Nat :=
  (cm.dstShift[k]? >>= (·[i]?)).join

/-- Element `k`'s write at slot `i`: one location; or, when an issue shifts it at run time (D54),
any location of the buffer (D23) and the offset the issue wrote. -/
def ChanModel.dstAccess (cm : ChanModel) (ip : IProgram) (k i : Nat) : List Access :=
  let dyn := (cm.dstDyn[k]? >>= (·[i]?)).getD []
  let dynReads : List Access := dyn.filterMap fun (h, _) => match h with
    | .result e _ => some ⟨ip.resultBuf, .read, [Int.ofNat e]⟩
    | _ => none
  let whole (b : Nat) : Access := ⟨b, .write, (List.range ip.buffers[b]!.type.numel).map Int.ofNat⟩
  match cm.dstAt k i, cm.dstShiftAt k i with
  | some (b, _), some iss => [whole b, ⟨ip.resultBuf, .read, [Int.ofNat iss]⟩] ++ dynReads
  | some (b, q), none => if dyn.isEmpty then [⟨b, .write, [q]⟩] else whole b :: dynReads
  | none, _ => []

/-- D23: the shift an element's run-time offsets give, from the values computed so far. -/
def dynValue (m : MState) (dyn : List (HVal × Int)) : Option Int :=
  dyn.foldlM (fun acc (h, st) => do
    let v ← m.resolve h >>= Val.toInt?
    pure (acc + v * st)) 0

/-- What each label reads and writes (`Chan.MemSpec.fp` on this program). -/
def IProgram.labelFp (ip : IProgram) (ca : ChanAnalysis) (cm : ChanModel)
    (fps0 : Array (List Access)) : Chan.LFp
  -- D62: a transfer reads, as it starts, the results its offsets, sizes or strides use.
  | .start v => (ip.offsetReads.getD v []).map fun (e, _) => ⟨ip.resultBuf, .read, [Int.ofNat e]⟩
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
    let whole (b : Nat) : List Int := (List.range ip.buffers[b]!.type.numel).map Int.ofNat
    let dyn := (cm.srcDyn[k]?).getD []
    let dynReads : List Access := dyn.filterMap fun (h, _) => match h with
      | .result e _ => some ⟨ip.resultBuf, .read, [Int.ofNat e]⟩
      | _ => none
    match (cm.srcLoc[k]?).join, (cm.srcShift[k]?).join with
    -- Shifted at run time (D54, D23): any element of the buffer, and the offsets read.
    | some (b, _), some i => [slotW, ⟨b, .read, whole b⟩, ⟨ip.resultBuf, .read, [Int.ofNat i]⟩] ++ dynReads
    | some (b, q), none =>
      if dyn.isEmpty then [slotW, ⟨b, .read, [q]⟩] else [slotW, ⟨b, .read, whole b⟩] ++ dynReads
    | none, _ => [slotW]
  | .push _ => []
  | .pull k i =>
    let slotR : Access := ⟨ip.slotBuf, .read, [k]⟩
    slotR :: cm.dstAccess ip k i
  | .xfer k =>
    let slotR : Access := ⟨ip.slotBuf, .read, [k]⟩
    slotR :: ((List.range ((cm.dstLoc[k]?.map (·.length)).getD 0)).flatMap fun i => cm.dstAccess ip k i)

structure LState where
  m : MState
  slots : Std.HashMap Nat Val := {}
  /-- D54: the offset each issue gave when it ran. -/
  shifts : Std.HashMap Nat Int := {}

/-- The memory, taken out of the state, and the state without it: a later `insert` on the
memory then updates it in place instead of copying it (it is no longer shared with the state). -/
@[inline] def LState.takeMem (s : LState) : Std.HashMap (Nat × Int) Val × LState :=
  (s.m.mem, { s with m := { s.m with mem := {} } })

@[inline] def LState.putMem (s : LState) (mem : Std.HashMap (Nat × Int) Val) : LState :=
  { s with m := { s.m with mem } }

/-- The same for the slots of elements in flight. -/
@[inline] def LState.takeSlots (s : LState) : Std.HashMap Nat Val × LState :=
  (s.slots, { s with slots := {} })

/-- One label on concrete memory (`Chan.MemSpec.eff` on this program). -/
def IProgram.fireLabel (ctx : IRContext OpCode) (ip : IProgram) (ca : ChanAnalysis)
    (cm : ChanModel) (s : LState) (l : Chan.Label) : LState := Id.run do
  if s.m.fault.isSome then return s
  -- A function of the state it is given (not a closure over `s`), so that `s` is not kept alive
  -- and its memory can be updated in place.
  let freed (s : LState) (who : String) : LState :=
    { s with m := { s.m with fault := some s!"{who}: a buffer it uses was deallocated" } }
  match l with
  | .start _ | .push _ => return s
  | .finish v =>
    if cm.dmaEvents.contains v then return s
    -- D54: an issue reads its offset when it runs.
    if let some ii := ip.issues[v]? then
      if let some ov := ii.offset then
        match ip.ctxs[v]!.env[ov]? >>= s.m.resolve >>= Val.toInt? with
        | some n => return { s with shifts := s.shifts.insert v n }
        | none => return { s with m := { s.m with fault := some s!"event {v} (air.channel.issue): its offset is not known when it runs" } }
      return s
    match ca.endpoints[v]? with
    | some ep =>
      if ep.isPut then return s
      if s.m.freed.contains ep.buf then return freed s s!"event {v}"
      let zero := zeroOf ip.buffers[ep.buf]!.type
      let (mem₀, s) := s.takeMem
      let mut mem := mem₀
      for (q, isPad) in ep.dst do
        if isPad then mem := mem.insert (ep.buf, q) zero
      return s.putMem mem
    | none => return { s with m := ip.finish ctx v s.m }
  | .read k =>
    let b := cm.srcBuf[k]!
    if s.m.freed.contains b then return freed s s!"the read of element {k}"
    let some dshift := dynValue s.m ((cm.srcDyn[k]?).getD [])
      | return { s with m := { s.m with fault := some s!"the read of element {k}: an offset computed by an event is not known yet" } }
    let shift := dshift + match (cm.srcShift[k]?).join with
      | some i => s.shifts.getD i 0
      | none => 0
    match (cm.srcLoc[k]?).join with
    | some (b', q) =>
      if q + shift < 0 || q + shift ≥ ip.buffers[b']!.type.numel then
        return { s with m := { s.m with fault := some s!"the read of element {k}: position {q + shift} is outside {ip.buffers[b']!.name}" } }
      let v := s.m.mem[(b', q + shift)]?.getD .undef
      let (slots, s) := s.takeSlots
      return { s with slots := slots.insert k v }
    | none =>
      let (slots, s) := s.takeSlots
      return { s with slots := slots.insert k (zeroOf ip.buffers[b]!.type) }
  | .pull k i =>
    let some (b, q₀) := cm.dstAt k i | return s
    let some dshift := dynValue s.m ((cm.dstDyn[k]? >>= (·[i]?)).getD [])
      | return { s with m := { s.m with fault := some s!"element {k}'s write: an offset computed by an event is not known yet" } }
    let q := q₀ + dshift + ((cm.dstShiftAt k i).map (s.shifts.getD · 0)).getD 0
    if s.m.freed.contains b then return freed s s!"element {k}'s write"
    if q < 0 || q ≥ ip.buffers[b]!.type.numel then
      return { s with m := { s.m with fault := some s!"element {k}'s write: position {q} is outside {ip.buffers[b]!.name}" } }
    let v := s.slots[k]?.getD .undef
    let (mem, s) := s.takeMem
    return s.putMem (mem.insert (b, q) v)
  | .xfer k =>
    let n := (cm.dstLoc[k]?.map (·.length)).getD 0
    let v := s.slots[k]?.getD .undef
    let shifts := s.shifts
    -- What the offsets read, without the memory (so that the memory is not shared).
    let m0 : MState := { s.m with mem := {} }
    let (mem₀, s) := s.takeMem
    let mut mem := mem₀
    for i in [0:n] do
      let some (b, q₀) := cm.dstAt k i | continue
      let some dshift := dynValue m0 ((cm.dstDyn[k]? >>= (·[i]?)).getD [])
        | let s := s.putMem mem
          return { s with m := { s.m with fault := some s!"element {k}'s write: an offset computed by an event is not known yet" } }
      let q := q₀ + dshift + ((cm.dstShiftAt k i).map (shifts.getD · 0)).getD 0
      if m0.freed.contains b then return freed s s!"element {k}'s write"
      if q < 0 || q ≥ ip.buffers[b]!.type.numel then
        let s := s.putMem mem
        return { s with m := { s.m with fault := some s!"element {k}'s write: position {q} is outside {ip.buffers[b]!.name}" } }
      mem := mem.insert (b, q) v
    return s.putMem mem

/-- The checked verdicts: an execution, whether it completes (`none`: internal error), whether it
is race-free (`Chan.racesOkE`), and witnesses of races for messages. -/
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
  -- `outcome_uniqueH` needs `Chan.wfB`; a model that fails it is an internal error.
  let c := if Chan.wfB cp then Chan.checkH cp idx t else none
  if c == some true && checkRaces then
    -- Orders between positions come from the event graph (`Chan.racesOkE`): no matrix over
    -- every label of the execution.
    let ok := Chan.racesOkE cp idx fp t
    let ws := if ok then [] else Chan.raceWitnessesE cp idx fp t
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
