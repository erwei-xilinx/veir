module

public import Veir.Air.Running
public import Veir.Air.LoopCert

namespace Veir.Air

@[expose] public section

/-! # Templates from sampled instantiations (phase 2a, `SCALE_DESIGN.md` §3.1)

The extraction of a `LoopCert.Template` from IR. Like `Instance.lean`, this is trusted: the
template is taken to be what the program stands for, for every trip count of its symbolic loops
(`LoopCert.Realizes`), and is not cross-checked against a full instantiation.

The program is instantiated with every *symbolic* loop (a trip count not known, or large) run
`sampleN` times (`instantiate`'s sampling); each event and buffer records the symbolic loops and
iterations it was made in. Then:
- an event of the template is an event of the sample up to its symbolic iterations: the loops it
  is in and its rank among the events made in the same iterations. Every iteration must make the
  same events (else the loop's body depends on its iteration, and the program is refused);
- an edge of the template is a dependency of the sample generalized to a pattern (`LoopCert.Rel`
  per loop), kept only if every pair of instances of the sample the pattern relates is a
  dependency. A dependency only an empty loop gives (its result is its initial value) comes from
  a sample with that loop empty, guarded by its emptiness;
- the footprint of a template event is what the labels it covers (it starts before them and
  finishes after them) access in each iteration, which must shift by a constant per iteration of
  each loop. Stream slots are exempt (`LoopCert.Realizes.exempt_ordered`); event results are one
  location per instance, read in the same iteration as written (else refused).
-/

namespace LoopTemplate

open LoopCert

/-- Iterations of each symbolic loop in the sample. -/
def sampleN : Nat := 3

/-- Per item made in `frames`: its loops, and its rank among the items made in the same
iterations. -/
def groups (frames : Array (List (Nat × Nat))) : Array (List Nat × Nat) := Id.run do
  let mut count : Std.HashMap (List (Nat × Nat)) Nat := {}
  let mut out := #[]
  for fr in frames do
    let r := count.getD fr 0
    count := count.insert fr (r + 1)
    out := out.push (fr.map (·.1), r)
  return out

/-- Every iteration vector of loops `ls`, `trips L` iterations each. -/
def kvecs (trips : Nat → Nat) : List Nat → List (List Nat)
  | [] => [[]]
  | L :: ls => (List.range (trips L)).flatMap fun k => (kvecs trips ls).map (k :: ·)

/-- An iteration function from loops and iterations. -/
def iterOf (ls : List Nat) (ks : List Nat) : Iter := fun L =>
  match (ls.zip ks).find? (·.1 == L) with
  | some (_, k) => k
  | none => 0

/-- What one sample says, in the template's numbering. -/
structure Sample where
  ip : IProgram
  /-- Per event: its template event and iterations (one per loop of the template event). -/
  tev : Array Nat
  kOf : Array (List Nat)
  /-- Per template event: its loops. -/
  tloops : Array (List Nat)
  /-- The event of each instance. -/
  inst : Std.HashMap (Nat × List Nat) Nat
  /-- Per buffer: its template buffer and the iterations it was made in. -/
  tbuf : Array Nat
  bufK : Array (List Nat)
  tbufLoops : Array (List Nat)

/-- Number groups in order of first appearance. -/
def numberGroups (gs : Array (List Nat × Nat)) (known : Std.HashMap (List Nat × Nat) Nat) :
    Array Nat × Std.HashMap (List Nat × Nat) Nat := Id.run do
  let mut ids := known
  let mut out := #[]
  for g in gs do
    match ids[g]? with
    | some i => out := out.push i
    | none =>
      out := out.push ids.size
      ids := ids.insert g ids.size
  return (out, ids)

/-- A sample in the numbering of `ref` (loops by their key; events and buffers by group), or in
its own when `ref` is `none`. `trips` gives each loop's iterations in this sample. -/
def sampleOf (ip : IProgram) (ref : Option (Sample × Std.HashMap (List Nat × Nat) Nat ×
    Std.HashMap (List Nat × Nat) Nat)) (trips : Nat → Nat) :
    Except String (Sample × Std.HashMap (List Nat × Nat) Nat × Std.HashMap (List Nat × Nat) Nat) := do
  -- Loops: by key, in the reference's numbering.
  let loopId ← ip.sample.symLoops.mapM fun (key, _) =>
    match ref with
    | none => pure (ip.sample.symLoops.findIdx? (·.1 == key)).get!
    | some (r, _, _) =>
      match r.ip.sample.symLoops.findIdx? (·.1 == key) with
      | some i => pure i
      | none => throw "a symbolic loop appears only when another is empty"
  let tr (fr : List (Nat × Nat)) := fr.map fun (L, k) => (loopId[L]!, k)
  let evFr := ip.sample.evFrames.map tr
  let bufFr := ip.sample.bufFrames.map tr
  let (tev, evIds) := numberGroups (groups evFr) ((ref.map (·.2.1)).getD {})
  let (tbuf, bufIds) := numberGroups (groups bufFr) ((ref.map (·.2.2)).getD {})
  let mut tloops : Array (List Nat) := Array.replicate evIds.size []
  for (g, i) in evIds.toList do tloops := tloops.set! i g.1
  let mut tbufLoops : Array (List Nat) := Array.replicate bufIds.size []
  for (g, i) in bufIds.toList do tbufLoops := tbufLoops.set! i g.1
  let kOf := evFr.map (·.map (·.2))
  let mut inst : Std.HashMap (Nat × List Nat) Nat := {}
  for v in [0:tev.size] do
    let key := (tev[v]!, kOf[v]!)
    if inst.contains key then throw "two events of one iteration have the same place"
    inst := inst.insert key v
  -- Every iteration makes the same events, from the same ops.
  for t in [0:tloops.size] do
    let mut op? : Option OperationPtr := none
    for ks in kvecs trips tloops[t]! do
      match inst[(t, ks)]? with
      | none =>
        if ref.isNone || (tloops[t]!.all fun L => trips L > 0) then
          if (inst.toList.any fun ((t', _), _) => t' == t) then
            throw "the events of a symbolic loop's iterations differ (the body depends on the iteration)"
      | some v =>
        let op := ip.prog.events[v]!.op
        if op? != none && op? != some op then
          throw "the events of a symbolic loop's iterations differ (the body depends on the iteration)"
        op? := some op
  return ({ ip, tev, kOf, tloops, inst, tbuf, bufK := bufFr.map (·.map (·.2)), tbufLoops },
    evIds, bufIds)

/-- The patterns a dependency from instance `(tu, ku)` to `(tv, kv)` suggests, most general first. -/
def candidates (lu lv : List Nat) (ku kv : List Nat) (trips : Nat → Nat) : List Pat :=
  let iu := iterOf lu ku
  let iv := iterOf lv kv
  let loops := (lu ++ lv).eraseDups
  let opts (L : Nat) : List Rel :=
    match lu.contains L, lv.contains L with
    | true, true =>
      if iu L == iv L then [.eq] else if iv L == iu L + 1 then [.succ] else []
    | true, false => .any :: (if iu L + 1 == trips L then [.last] else [])
    | false, true => .any :: (if iv L == 0 then [.first] else [])
    | false, false => [.any]
  let pats := loops.foldr (init := [([] : Pat)]) fun L acc =>
    (opts L).flatMap fun r => acc.map ((L, r) :: ·)
  pats.map fun π => π.filter (·.2 != .any)

/-- Whether every pair of instances `π` relates is a dependency in the sample. -/
def validates (s : Sample) (edges : Std.HashSet (Nat × Nat)) (trips : Nat → Nat) (tu tv : Nat)
    (π : Pat) : Bool :=
  let lu := s.tloops[tu]!
  let lv := s.tloops[tv]!
  let ls : Loops := s.tloops
  (kvecs trips lu).all fun ku => (kvecs trips lv).all fun kv =>
    let ia := iterOf lu ku
    let ib := iterOf lv kv
    let rel := (lu ++ lv).eraseDups.all fun L =>
      (π.get L).holds (trips L) (side (inL ls tu L) (ia L)) (side (inL ls tv L) (ib L))
    !rel || match s.inst[(tu, ku)]?, s.inst[(tv, kv)]? with
      | some u, some v => edges.contains (u, v)
      | _, _ => false

/-- The template edges a sample's dependencies give, guarded by `guard`. -/
def edgeFacts (s : Sample) (trips : Nat → Nat) (guard : Guard) : List Fact := Id.run do
  let g := s.ip.prog.graph
  let mut edges : Std.HashSet (Nat × Nat) := {}
  for v in [0:s.tev.size] do
    for u in g.predsOf v do edges := edges.insert (u, v)
  let mut seen : Std.HashSet (Nat × Nat × Pat) := {}
  let mut out := #[]
  for v in [0:s.tev.size] do
    for u in g.predsOf v do
      let tu := s.tev[u]!
      let tv := s.tev[v]!
      for π in candidates s.tloops[tu]! s.tloops[tv]! s.kOf[u]! s.kOf[v]! trips do
        if seen.contains (tu, tv, π) then continue
        seen := seen.insert (tu, tv, π)
        if validates s edges trips tu tv π then
          out := out.push { src := tu, dst := tv, pat := π, guard }
          break
  return out.toList

/-- Positions as a sorted array without repeats. -/
def sortedSet (xs : List Int) : Array Int := (dedupSorted (xs.mergeSort (· ≤ ·))).toArray

/-- The access an instance family makes, if its positions shift by a constant per iteration of
each loop: `offs` the positions of the first instance, `coef` the shifts. -/
def affineFit (ls : List Nat) (trips : Nat → Nat) (P : List Nat → Array Int) :
    Option (List (Nat × Int)) := do
  let zero := ls.map fun _ => 0
  let P0 := P zero
  let mut coef : List (Nat × Int) := []
  for L in ls, j in [0:ls.length] do
    if trips L < 2 then continue
    let P1 := P (zero.set j 1)
    if P1.size != P0.size then none
    let d : Int := if P0.isEmpty then 0 else P1[0]! - P0[0]!
    if d != 0 then coef := coef ++ [(L, d)]
  for ks in kvecs trips ls do
    let shift := (ls.zip ks).foldl (fun acc (L, k) => acc + ((coef.find? (·.1 == L)).map (·.2)).getD 0 * k) 0
    let Pk := P ks
    if Pk.size != P0.size then none
    for i in [0:P0.size] do
      if Pk[i]! != P0[i]! + shift then none
  return coef

/-- The footprints of the template events: per template event, its accesses. Template buffers
are the sample's buffers' groups, then one result location per template event. -/
def footprints (ctx : IRContext OpCode) (s : Sample) (trips : Nat → Nat) :
    Except String (Array (List TAcc) × Array (List Nat)) := do
  let ip := s.ip
  let ca ← ip.analyzeChannels
  let orders ← ip.putOrders ca
  let some o := orders.head? | throw "no order of puts"
  let cm ← ip.chanModel ca o
  let (fps0, _) := ip.footprints ctx
  let fp := ip.labelFp ca cm fps0
  let nTB := s.tbufLoops.size
  let nT := s.tloops.size
  -- Per (template event, template buffer, write, iterations): positions. Each array is taken out
  -- of the map before it grows, so that it grows in place.
  let mut acc : Std.HashMap (Nat × Nat × Bool × List Nat) (Array Int) := {}
  -- Each covered access: the event covering it, the buffer, whether it writes, and the positions
  -- (`none`: the whole buffer, D23, recorded once per event and buffer).
  let mut covered : Array (Nat × Nat × Bool × Option (List Int)) := #[]
  let mut wholeSeen : Std.HashSet (Nat × Nat × Bool) := {}
  let resultRead (u e : Nat) : Nat × Nat × Bool × Option (List Int) := (u, ip.resultBuf, false, some [Int.ofNat e])
  for v in [0:ip.prog.events.size] do
    for a in fp (.start v) ++ fp (.finish v) do
      covered := covered.push (v, a.buf, a.kind == .write, some a.elems)
  -- Element labels, as `labelFp` gives them (`.read`, `.pull`, `.xfer`), without listing a whole
  -- buffer per element.
  for k in [0:cm.prog.elems.size] do
    let e := cm.prog.elems[k]!
    if let some src := e.src then
      let dyn := (cm.srcDyn[k]?).getD []
      for (h, _) in dyn do
        if let .result r _ := h then covered := covered.push (resultRead src r)
      match (cm.srcLoc[k]?).join, (cm.srcShift[k]?).join with
      | some (b, _), some i =>
        covered := covered.push (resultRead src i)
        if !wholeSeen.contains (src, b, false) then
          wholeSeen := wholeSeen.insert (src, b, false); covered := covered.push (src, b, false, none)
      | some (b, q), none =>
        if dyn.isEmpty then covered := covered.push (src, b, false, some [q])
        else if !wholeSeen.contains (src, b, false) then
          wholeSeen := wholeSeen.insert (src, b, false); covered := covered.push (src, b, false, none)
      | none, _ => pure ()
    for i in [0:e.dsts.length] do
      if let some (some d) := e.dsts[i]? then
        let dyn := (cm.dstDyn[k]? >>= (·[i]?)).getD []
        for (h, _) in dyn do
          if let .result r _ := h then covered := covered.push (resultRead d r)
        match cm.dstAt k i, cm.dstShiftAt k i with
        | some (b, _), some iss =>
          covered := covered.push (resultRead d iss)
          if !wholeSeen.contains (d, b, true) then
            wholeSeen := wholeSeen.insert (d, b, true); covered := covered.push (d, b, true, none)
        | some (b, q), none =>
          if dyn.isEmpty then covered := covered.push (d, b, true, some [q])
          else if !wholeSeen.contains (d, b, true) then
            wholeSeen := wholeSeen.insert (d, b, true); covered := covered.push (d, b, true, none)
        | none, _ => pure ()
  for (u, buf, w, elems?) in covered do
    if buf == ip.slotBuf then continue
    let t := s.tev[u]!
    let lu := s.tloops[t]!
    let ku := s.kOf[u]!
    let iu := iterOf lu ku
    let elems := match elems? with
      | some es => es
      | none => (List.range ip.buffers[buf]!.type.numel).map Int.ofNat
    -- The template buffer, and the template positions.
    let mut parts : List (Nat × Int) := []
    if buf == ip.resultBuf then
      for e in elems do
        let r := e.toNat
        let tr := s.tev[r]!
        let lr := s.tloops[tr]!
        let ir := iterOf lr s.kOf[r]!
        if !(lr.all fun L => lu.contains L && iu L == ir L) then
          throw s!"event {u} reads the result of event {r} of another iteration of a symbolic loop"
        parts := parts ++ [(nTB + tr, 0)]
    else
      let tb := s.tbuf[buf]!
      let lb := s.tbufLoops[tb]!
      let ib := iterOf lb s.bufK[buf]!
      if !(lb.all fun L => lu.contains L && iu L == ib L) then
        throw s!"event {u} accesses a buffer of another iteration of a symbolic loop"
      parts := elems.map (tb, ·)
    for (tb, q) in parts do
      let key := (t, tb, w, ku)
      let arr := acc.getD key #[]
      acc := acc.erase key
      acc := acc.insert key (arr.push q)
  let mut fps : Array (List TAcc) := Array.replicate nT []
  let mut keys : Std.HashSet (Nat × Nat × Bool) := {}
  for ((t, tb, w, _), _) in acc.toList do keys := keys.insert (t, tb, w)
  for (t, tb, w) in keys.toList do
    let ls := s.tloops[t]!
    let P (ks : List Nat) : Array Int := sortedSet (acc.getD (t, tb, w, ks) #[]).toList
    let some coef := affineFit ls trips P
      | throw s!"an access of a symbolic loop does not shift by a constant per iteration"
    fps := fps.set! t ({ buf := tb, write := w, base := 0, coef, offs := P (ls.map fun _ => 0) } :: fps[t]!)
  let bufLoops := s.tbufLoops ++ s.tloops
  return (fps, bufLoops.toList.toArray)

/-- A sample with the values events compute (D59, D62): the rounds of `instantiateRunning`, which
propose values by running the sample, without its checks (the template is trusted). A transfer
value no round proposes stays over-approximated (D23). -/
partial def sampleWithValues (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int)
    (zero : List SymKey) : Except String IProgram :=
  let rec go (decisions : Std.HashMap ResultKey Int) (round : Nat) : Except String IProgram := do
    if round > maxRounds then throw s!"more than {maxRounds} rounds of run-time values"
    let ip ← instantiate ctx func scalars decisions (some sampleN) zero
    if ip.decides.isEmpty && ip.offsets.isEmpty then return ip
    if ip.complete && !(ip.offsets.any (·.values.isNone)) then return ip
    let vals ← if ip.complete then pure ((ip.proposeValues ctx).toOption.getD [])
      else ip.proposeValues ctx
    let fresh := vals.filter fun (k, _) => !decisions.contains k
    if !fresh.isEmpty then
      return ← go (fresh.foldl (fun m (k, n) => m.insert k n) decisions) (round + 1)
    if let some d := ip.decides.find? (·.values.isNone) then
      throw s!"'{opName ctx ip.prog.events[d.event]!.op}': the value deciding it is not computed in the sample"
    return ip
  go {} 0

/-- The template of a function, or why there is none; `none` when it has no symbolic loop. -/
def template (ctx : IRContext OpCode) (func : OperationPtr) (scalars : List Int) :
    Except String (Option (Template × Sample)) := do
  let sampled (zero : List SymKey) : Except String IProgram := sampleWithValues ctx func scalars zero
  let ip ← sampled []
  if ip.sample.symLoops.isEmpty then return none
  let trips : Nat → Nat := fun _ => sampleN
  let (s, evIds, bufIds) ← sampleOf ip none trips
  let mut edges := edgeFacts s trips []
  -- Dependencies only an empty loop gives.
  for (key, _) in ip.sample.symLoops, L in [0:ip.sample.symLoops.size] do
    -- Only its edges are used: values are needed only when control flow depends on them (D59).
    let ipZ ← if ip.decides.isEmpty then instantiate ctx func scalars {} (some sampleN) [key]
      else sampled [key]
    let tripsZ : Nat → Nat := fun L' => if L' == L then 0 else sampleN
    let (sZ, _, _) ← sampleOf ipZ (some (s, evIds, bufIds)) tripsZ
    edges := edges ++ edgeFacts sZ tripsZ [(L, true)]
  let (fps, bufLoops) ← footprints ctx s trips
  let fps := fps ++ Array.replicate (s.tloops.size - fps.size) []
  -- Known trip counts, small enough to enumerate.
  let known := (ip.sample.symLoops.toList.zipIdx.filterMap fun ((_, _, t), L) =>
    t.bind fun N => if N ≤ 64 then some (L, N) else none)
  return some ({ nl := ip.sample.symLoops.size, loops := s.tloops, known, bufLoops, fps, edges }, s)

/-- The first pair `certOk` rejects, for the report: two template events and the region. -/
def firstFailure (T : Template) : Option (Nat × Nat × LoopCert.Region) := Id.run do
  let m := byPair T.facts
  let facts (v w : Nat) := m.getD (v, w) []
  for v in [0:T.loops.size] do
    for w in [0:T.loops.size] do
      for a in T.fps[v]?.getD [] do
        for b in T.fps[w]?.getD [] do
          if !(a.buf == b.buf && (a.write || b.write)) then continue
          let C := (T.loops[v]?.getD []).filter (inL T.loops w)
          for σ in regions C do
            if !(pairOk T facts v w a b) then
              let ok := (v == w && σ.all (·.2 == .eq)) ||
                (T.bufLoops[a.buf]?.getD []).any (fun L => inL T.loops v L && inL T.loops w L &&
                  ordOf σ L != .eq) ||
                orderedOk T.loops (facts v w ++ facts w v) v w σ || disjointOk T.nl T.loops T.known v w σ a b
              if !ok then return some (v, w, σ)
  return none

end LoopTemplate

end

end Veir.Air
