module

public import Veir.Air.LoopTemplate
public import Veir.Air.LoopDead

namespace Veir.Air

@[expose] public section

/-! # Phase 2b: the certificate of completion (`SCALE_DESIGN.md` §3.2)

What is extracted here is trusted, as `LoopTemplate` is: the streams of the template (from the
sample's channel model) and which loops have equal lengths (from their bounds in the IR). The
rest of the certificate is proposed here and checked by `LoopDead.DCert.deadOk`
(`LoopDead.completes_of_deadOk`): the alignment classes and scales, the order of the classes, where
each event is outside a class, the offsets and the order of one time unit.

Two loops' trip counts are equal when they are the same constant, or the same expression of the
same values: the same arith/affine ops in the same order, of the function's arguments and
constants, through the `args` of launch, segment and herd (decided 2026-11-19). A trip count is
`c * E`, `c` a constant; loops `n_L = c_L * E` and `n_L' = c_L' * E` align with scales `s_L * c_L =
s_L' * c_L'`.
-/

namespace LoopDeadGen

open LoopCert LoopDead

/-- An expression of the values a loop bound is computed from. -/
inductive BExpr where
  | const (n : Int)
  | arg (i : Nat)
  | op (name : String) (attr : String) (args : List BExpr)
deriving BEq, Repr, Inhabited, Hashable

/-- The integer an op without operands computes, if it is one. -/
def constOf (ctx : IRContext OpCode) (op : OperationPtr) : Option Int :=
  if op.getNumOperands! ctx != 0 then none else
  match evalHostArith ctx op {} with
  | .ok env => env[(ValuePtr.opResult ⟨op, 0⟩)]? >>= knownIntH?
  | .error _ => none

def castNames : List String :=
  ["arith.index_cast", "arith.index_castui", "arith.extsi", "arith.extui", "arith.trunci"]

/-- The expression of `v`: constants, the function's arguments, arith and affine ops, through the
`args` of launch, segment and herd. Anything else (an iteration's index, a tile's id, a value an
event computes) has no expression. -/
partial def exprOf (ctx : IRContext OpCode) (v : ValuePtr) : Except String BExpr := do
  match v with
  | .blockArgument ⟨blk, i⟩ =>
    let some region := blk.getParent! ctx | throw "a block argument outside an op"
    let some op := region.getParent! ctx | throw "a block argument outside an op"
    let name := opName ctx op
    if name == "func.func" then return .arg i
    if hierarchyOps.contains name then
      let props := unregProps ctx op
      let isRank := name == "air.rank"
      let some seg := denseInts (findProp props "operandSegmentSizes")
        | throw s!"'{name}': missing operandSegmentSizes"
      let nDeps := seg[0]!.toNat
      let nUni := if isRank then seg[1]!.toNat else 0
      let nSizes := seg[if isRank then 2 else 1]!.toNat
      let operands := op.getOperands! ctx
      if i < nSizes then throw s!"a bound depends on the id of '{name}'"
      if i < 2 * nSizes then return ← exprOf ctx operands[nDeps + nUni + (i - nSizes)]!
      return ← exprOf ctx operands[nDeps + nUni + nSizes + (i - 2 * nSizes)]!
    throw s!"a bound depends on an argument of '{name}' (an iteration's index)"
  | .opResult ⟨op, idx⟩ =>
    let name := opName ctx op
    if let some n := constOf ctx op then return .const n
    if castNames.contains name then return ← exprOf ctx (op.getOperands! ctx)[0]!
    if name.startsWith "arith." || name == "affine.apply" then
      let args ← (op.getOperands! ctx).toList.mapM (exprOf ctx)
      let attr := if name == "affine.apply" then (affineText ctx op "map").getD "" else
        if name == "arith.cmpi" then toString (repr (findProp (unregProps ctx op) "predicate")) else ""
      return .op s!"{name}#{idx}" attr args
    throw s!"a bound is computed by '{name}'"

/-- A trip count as `c * E`. -/
def splitMul : BExpr → Nat × BExpr
  | .const n => if n > 0 then (n.toNat, .const 1) else (0, .const 0)
  | .op "arith.muli#0" _ [x, .const c] => if c > 0 then (c.toNat, x) else (1, .op "arith.muli#0" "" [x, .const c])
  | .op "arith.muli#0" _ [.const c, x] => if c > 0 then (c.toNat, x) else (1, .op "arith.muli#0" "" [.const c, x])
  | e => (1, e)

/-- A symbolic loop's trip count, `c * E`. -/
def tripOf (ctx : IRContext OpCode) (key : SymKey) : Except String (Nat × BExpr) := do
  let (op, _, dim) := key
  let name := opName ctx op
  let operands := op.getOperands! ctx
  let (lbV, ubV, stV) ← match name with
    | "scf.for" => pure (operands[0]!, operands[1]!, operands[2]!)
    | "scf.parallel" =>
      let some seg := denseInts (findProp (unregProps ctx op) "operandSegmentSizes")
        | throw "scf.parallel: missing operandSegmentSizes"
      let n := seg[0]!.toNat
      pure (operands[dim]!, operands[n + dim]!, operands[2 * n + dim]!)
    | _ => throw s!"the trip count of '{name}' is not read as an expression"
  let lb ← exprOf ctx lbV
  let ub ← exprOf ctx ubV
  let st ← exprOf ctx stV
  match lb, st with
  | .const 0, .const 1 => return splitMul ub
  | .const _, .const _ => return (1, .op "trip" "" [ub, lb, st])
  | _, _ => throw "a symbolic loop's lower bound or step is not a constant"

/-! ### Streams of the sample -/

/-- The runs one side of a stream moves: per element (in stream order) the event moving it, if
any. Consecutive elements of one event instance are one run; each iteration of the side's loop
(its template events' one loop; none: one iteration) must move the same runs. Returns the runs of
one iteration and the elements per iteration; no element moved by anything: no runs. -/
def runsOf (s : LoopTemplate.Sample) (movers : Array (Option Nat)) : Except String (List Seg × Nat) := do
  if movers.all (·.isNone) then return ([], 0)
  -- The sample runs every symbolic loop the same number of times: when the two ends' loops differ
  -- in length (an integer multiple), one end moves only a first part of the stream there.
  let moved := movers.toList.takeWhile (·.isSome)
  if movers.toList.drop moved.length |>.any (·.isSome) then
    throw "a stream whose elements its puts or gets move with gaps"
  -- Runs: (event instance, count), in order.
  let mut runs : Array (Nat × Nat) := #[]
  for o in moved do
    let u := o.get!
    match runs.back? with
    | some (u', c) => if u' == u then runs := runs.pop.push (u, c + 1) else runs := runs.push (u, 1)
    | none => runs := runs.push (u, 1)
  let tevs := (runs.toList.map fun (u, _) => s.tev[u]!).eraseDups
  let loops := tevs.map fun t => s.tloops[t]!
  let some l0 := loops.head? | throw "a stream without runs"
  if loops.any (· != l0) then throw "a stream's puts or gets are in different loops"
  if l0.length > 1 then throw "a stream's puts or gets are in more than one symbolic loop"
  -- Group the runs by iteration of the loop, in order.
  let iterOf (u : Nat) : Nat := (s.kOf[u]!).head?.getD 0
  let mut iters : Array (Array (Nat × Nat)) := #[]
  let mut cur : Option Nat := none
  for (u, c) in runs do
    let q := iterOf u
    if cur != some q then
      if q != iters.size then throw "a stream's iterations are not in order"
      iters := iters.push #[]
      cur := some q
    iters := iters.modify (iters.size - 1) (·.push (s.tev[u]!, c))
  let some first := iters[0]? | throw "a stream without runs"
  let cut := moved.length < movers.size
  -- Every iteration moves the same runs; when the stream is cut short (above), the last one may
  -- stop early, and an earlier one is whole.
  let whole := if cut then iters.pop else iters
  if whole.isEmpty then throw "a stream with no whole iteration in the sample"
  if whole.any (· != first) then throw "a stream moves different runs in different iterations"
  if cut then
    if let some last := iters.back? then
      let n := last.size
      let ok := n ≤ first.size && n > 0 &&
        (List.range (n - 1)).all (fun i => last[i]! == first[i]!) &&
        last[n - 1]!.1 == first[n - 1]!.1 && last[n - 1]!.2 ≤ first[n - 1]!.2
      if !ok then throw "a stream moves different runs in different iterations"
  let mut off := 0
  let mut segs : List Seg := []
  for (t, c) in first do
    segs := segs ++ [{ ev := t, off, m := c }]
    off := off + c
  return (segs, off)

/-- Per slot: whether nothing gets the stream's elements there. -/
def slots0 (s : LoopTemplate.Sample) (chain : Array Nat) (elems : Array Chan.Elem) (nSlots : Nat) :
    List Bool :=
  let _ := s
  (List.range nSlots).map fun i => chain.all fun k => ((elems[k]!.dsts[i]?).bind id).isNone

/-- The sample's streams, as template streams (rates and ranks not yet given). -/
def streamsOf (s : LoopTemplate.Sample) : Except String (Array DStream) := do
  let ip := s.ip
  let ca ← ip.analyzeChannels
  let orders ← ip.putOrders ca
  if orders.length != 1 then throw "more than one order of puts (D52)"
  let cm ← ip.chanModel ca orders.head!
  let elems := cm.prog.elems
  -- Chains of elements: each stream's elements in order.
  let mut next : Std.HashMap Nat Nat := {}
  for k in [0:elems.size] do
    if let some j := elems[k]!.prev then next := next.insert j k
  let mut out : Array DStream := #[]
  -- Instance-local streams, one per signature (each instance of the events has its own chain).
  let mut locals : Std.HashMap (Nat × List (Option Nat) × Nat × Bool) Unit := {}
  for k0 in [0:elems.size] do
    if elems[k0]!.prev.isSome then continue
    let mut chain : Array Nat := #[k0]
    let mut cur := k0
    while true do
      match next[cur]? with
      | some k' => chain := chain.push k'; cur := k'
      | none => break
    let e0 := elems[k0]!
    let nSlots := e0.dsts.length
    if chain.any fun k => elems[k]!.buffered != e0.buffered then throw "a stream both buffered and not"
    -- One instance moves the whole chain at each end, inside symbolic loops: instance-local.
    let one (xs : Array (Option Nat)) : Option (Option Nat) :=
      if xs.all (·.isNone) then some none else
      match xs[0]? with
      | some (some u) => if xs.all (· == some u) then some (some u) else none
      | _ => none
    let srcOne := one (chain.map fun k => elems[k]!.src)
    let slotOne := (List.range nSlots).map fun i => one (chain.map fun k => (elems[k]!.dsts[i]?).bind id)
    if let some (some u) := srcOne then
      if !s.tloops[s.tev[u]!]!.isEmpty && slotOne.all (·.isSome) then
        let tP := s.tev[u]!
        let tGs := slotOne.map fun o => (o.get!).map (s.tev[·]!)
        let key := (tP, tGs, chain.size, e0.buffered)
        if !locals.contains key then
          locals := locals.insert key ()
          let m := chain.size
          let seg (t : Nat) : Seg := { ev := t, off := 0, m := m }
          let slots : List (List Seg × Nat) := tGs.map fun o =>
            match o with
            | some t => ([seg t], m)
            | none => ([], 0)
          out := out.push { puts := [seg tP], per := m, slots, buffered := e0.buffered, rate := 1,
                            πread := 0, πpush := 0, πpull := 0, πxfer := 0, isLocal := true }
        continue
    if chain.any fun k => elems[k]!.dsts.length != nSlots then throw "a stream's slots differ"
    if !e0.buffered && (slots0 s chain elems nSlots).any id then
      throw "an unbuffered stream (D51) that a slot has no get for: its puts never finish"
    -- Phases: loops feeding the stream in turn. Every side changes loops at the same elements.
    let loopsAt (o : Option Nat) : Option (List Nat) := o.map fun u => s.tloops[s.tev[u]!]!
    let cuts (movers : Array (Option Nat)) : List Nat :=
      (List.range movers.size).filter fun e => e > 0 && movers[e]!.isSome &&
        loopsAt movers[e]! != loopsAt movers[e - 1]!
    let putMovers := chain.map fun k => elems[k]!.src
    let slotMovers := (List.range nSlots).map fun i => chain.map fun k => (elems[k]!.dsts[i]?).bind id
    let bounds := cuts putMovers
    for m in slotMovers do
      if !(m.all (·.isNone)) && cuts m != bounds then
        throw "a stream whose puts and gets change loops at different elements"
    let pieces := (0 :: bounds).zip (bounds ++ [chain.size])
    let mut prev : Option Nat := none
    for (lo, hi) in pieces do
      let sub (m : Array (Option Nat)) := m.extract lo hi
      let (puts, per) ← runsOf s (sub putMovers)
      if puts.isEmpty then throw "a stream no put sends"
      let mut slots : List (List Seg × Nat) := []
      for m in slotMovers do
        slots := slots ++ [← runsOf s (sub m)]
      out := out.push { puts, per, slots, buffered := e0.buffered, rate := 0,
                        πread := 0, πpush := 0, πpull := 0, πxfer := 0, prevPhase := prev }
      prev := some (out.size - 1)
  return out

/-! ### Proposing the rest -/

partial def ufFind (par : Array Nat) (x : Nat) : Nat :=
  if par[x]! == x then x else ufFind par par[x]!

/-- A topological order of `n` nodes under `edges` (`a` before `b`), lowest first among the
ready; `none` on a cycle. -/
def topo (n : Nat) (edges : List (Nat × Nat)) : Option (Array Nat) := Id.run do
  let mut indeg := Array.replicate n 0
  let mut succ : Array (List Nat) := Array.replicate n []
  for (a, b) in edges do
    if a < n && b < n then
      indeg := indeg.modify b (· + 1)
      succ := succ.modify a (b :: ·)
  let mut rank := Array.replicate n 0
  let mut ready : List Nat := (List.range n).filter (indeg[·]! == 0)
  let mut done := 0
  while !ready.isEmpty do
    let x := ready.head!
    ready := ready.tail!
    rank := rank.set! x done
    done := done + 1
    for y in succ[x]! do
      indeg := indeg.modify y (· - 1)
      if indeg[y]! == 0 then ready := (ready ++ [y]).mergeSort (· ≤ ·)
  return if done == n then some rank else none

/-- The certificate of completion for template `T` of sample `s`, or why there is none. -/
def certificate (ctx : IRContext OpCode) (T : Template) (s : LoopTemplate.Sample) :
    Except String DCert := do
  if let some (a, b) := T.uncovered.head? then
    throw s!"a dependency of template event {b} on {a} is not a template edge"
  let nv := T.loops.size
  let nl := T.nl
  let keys := s.ip.sample.symLoops
  let streams0 ← streamsOf s
  let loopOf (v : Nat) : Option Nat := (T.loops[v]?.getD []).head?
  let sides (σ : DStream) : List (List Seg × Nat) := (σ.puts, σ.per) :: σ.slots
  -- Alignment classes: the loops of each stream's runs.
  let mut par := (List.range nl).toArray
  for σ in streams0 do
    if σ.isLocal then continue
    let ls := (sides σ).flatMap fun (segs, _) => segs.filterMap fun g => loopOf g.ev
    let nonEmpty := (sides σ).filter (!·.1.isEmpty)
    if !ls.isEmpty && ls.length != (nonEmpty.flatMap (·.1)).length then
      throw "a stream with a symbolic loop at some ends only"
    for (a, b) in ls.zip ls.tail do
      let (ra, rb) := (ufFind par a, ufFind par b)
      if ra != rb then par := par.set! ra rb
  let cls := (List.range nl).toArray.map (ufFind par)
  -- Scales: per class, its loops' trip counts `c_L * E` with one `E`.
  let mut scale := Array.replicate nl 1
  let mut csOf := Array.replicate nl 1
  for C in (cls.toList.eraseDups) do
    let ls := (List.range nl).filter (cls[·]! == C)
    if ls.length < 2 then continue
    let trips ← ls.mapM fun L => do
      let (c, E) ← (tripOf ctx keys[L]!.1).mapError (s!"loop {L}: " ++ ·)
      return (L, c, E)
    let E0 := trips.head!.2.2
    if trips.any (·.2.2 != E0) then
      throw s!"loops {ls} are tied by streams, but their trip counts are not the same expression"
    let TC := trips.foldl (fun acc (_, c, _) => Nat.lcm acc c) 1
    for (L, c, _) in trips do
      scale := scale.set! L (TC / c)
      csOf := csOf.set! L c
  -- Rates: elements per unit, equal at every end.
  let mut streams := #[]
  for σ in streams0 do
    if σ.isLocal then streams := streams.push σ; continue
    match σ.puts.head? >>= fun g => loopOf g.ev with
    | some Lp =>
      let K := σ.per * csOf[Lp]!
      for (segs, G) in σ.slots do
        if let some g := segs.head? then
          if G * csOf[(loopOf g.ev).get!]! != K then
            throw "a stream's puts and gets do not balance for every trip count"
      let TC := scale[Lp]! * csOf[Lp]!
      if TC == 0 || K % TC != 0 then throw "a stream's rate is not whole"
      streams := streams.push { σ with rate := K / TC }
    | none =>
      if σ.slots.any fun (segs, G) => !segs.isEmpty && G != σ.per then
        throw "a stream's puts and gets do not balance"
      streams := streams.push { σ with rate := 1 }
  -- Finer units, so that every run fills whole units of its own: per class a factor `f` dividing
  -- every rate, each rate over `f` dividing the stream's run sizes and offsets.
  let runGcd (σ : DStream) : Nat :=
    ((sides σ).flatMap fun (segs, _) => segs.flatMap fun g => [g.off, g.m]).foldl Nat.gcd 0
  for C in (cls.toList.eraseDups) do
    let inC := streams.toList.filter fun σ => !σ.isLocal &&
      (σ.puts.head? >>= fun g => loopOf g.ev).any (cls[·]! == C)
    if inC.isEmpty then continue
    let f := inC.foldl (fun acc σ => Nat.lcm acc (σ.rate / Nat.gcd σ.rate (runGcd σ))) 1
    if f ≤ 1 || inC.any (fun σ => σ.rate % f != 0) then continue
    streams := streams.map fun σ =>
      if inC.any (fun τ => τ.puts.head?.map (·.ev) == σ.puts.head?.map (·.ev)) then
        { σ with rate := σ.rate / f } else σ
    for L in [0:nl] do
      if cls[L]! == C then scale := scale.set! L (scale[L]! * f)
  -- The classes' order: outer loops' classes first.
  let classes := cls.toList.eraseDups
  let cIdx (C : Nat) : Nat := (classes.idxOf C)
  let mut nest : List (Nat × Nat) := []
  for v in [0:nv] do
    let ls := T.loops[v]!
    for (a, b) in ls.zip ls.tail do
      if cls[a]! != cls[b]! then nest := (cIdx cls[a]!, cIdx cls[b]!) :: nest
  -- A later phase's class ranks before the earlier phase's (`LoopDead.DCert.cmpPhase`).
  for σ in streams do
    if let some q := σ.prevPhase then
      match σ.puts.head? >>= (fun g => loopOf g.ev), (streams[q]? >>= (·.puts.head?)) >>= (fun g => loopOf g.ev) with
      | some a, some b => if cls[a]! != cls[b]! then nest := (cIdx cls[a]!, cIdx cls[b]!) :: nest
      | _, _ => pure ()
  let some crank := topo classes.length nest | throw "loops nest in both orders"
  let order := (classes.mergeSort fun a b => crank[cIdx a]! ≤ crank[cIdx b]!)
  -- Where each event is outside a class: after it when something inside reaches it, when it
  -- follows an event after it, or when another end of its stream is after it.
  let inside (v C : Nat) : Bool := (T.loops[v]!).any (cls[·]! == C)
  let ends (σ : DStream) : List Nat := (sides σ).flatMap fun (segs, _) => segs.map (·.ev)
  let mut top : Array (List Nat) := Array.replicate nv []
  for C in classes do
    let mut isTop : Array Bool := Array.replicate nv false
    let mut changed := true
    while changed do
      changed := false
      for f in T.edges do
        if !inside f.dst C && !isTop[f.dst]! && (inside f.src C || isTop[f.src]!) then
          isTop := isTop.set! f.dst true
          changed := true
      for σ in streams do
        -- The events of one side are where its first one is; a buffered stream's gets are no
        -- earlier than its puts, the ends of another meet.
        let putEnds := (σ.puts.map (·.ev)).filter (!inside · C)
        let getEnds := (σ.slots.flatMap fun (segs, _) => segs.map (·.ev)).filter (!inside · C)
        let groups : List (List Nat × List Nat) :=
          if σ.buffered && !σ.isLocal then [(putEnds, putEnds ++ getEnds), (getEnds, getEnds)]
          else [(putEnds ++ getEnds, putEnds ++ getEnds)]
        for (src, dst) in groups do
          if src.any (isTop[·]!) then
            for v in dst do
              if !isTop[v]! then isTop := isTop.set! v true; changed := true
    for v in [0:nv] do
      if isTop[v]! then top := top.modify v (C :: ·)
  -- Offsets: a run's event spans its run's units; others follow `eq` edges.
  let mut forced : Std.HashMap (Nat × Nat) (Nat × Nat) := {}
  for σ in streams do
    if σ.isLocal then continue
    for (segs, _) in sides σ do
      for g in segs do
        if let some L := loopOf g.ev then
          forced := forced.insert (g.ev, L) (g.off / σ.rate, (g.off + g.m - 1) / σ.rate)
  let mut sOff : Array (List (Nat × Nat)) := Array.replicate nv []
  let mut fOff : Array (List (Nat × Nat)) := Array.replicate nv []
  for L in [0:nl] do
    let evs := (List.range nv).filter fun v => (T.loops[v]!).contains L
    let mut so : Std.HashMap Nat Nat := {}
    let mut fo : Std.HashMap Nat Nat := {}
    for v in evs do
      if let some (a, b) := forced[(v, L)]? then
        so := so.insert v a
        fo := fo.insert v b
    for _ in [0:evs.length + 1] do
      for f in T.edges do
        if f.pat.get L == .eq && evs.contains f.src && evs.contains f.dst &&
            !forced.contains (f.dst, L) then
          let need := fo.getD f.src 0
          if so.getD f.dst 0 < need then so := so.insert f.dst need
          if fo.getD f.dst 0 < so.getD f.dst 0 then fo := fo.insert f.dst (so.getD f.dst 0)
    for v in evs do
      sOff := sOff.modify v ((L, so.getD v 0) :: ·)
      fOff := fOff.modify v ((L, fo.getD v 0) :: ·)
  let D0 : DCert := { T, cls, scale, order, top, sOff, fOff, πs := #[], πf := #[], streams }
  -- The order of one unit.
  let base := 2 * nv
  let mut πe : List (Nat × Nat) := (List.range nv).map fun v => (2 * v, 2 * v + 1)
  for f in T.edges do
    if lexChk (D0.cmpEdge f) true order && !lexChk (D0.cmpEdge f) false order then
      πe := (2 * f.src + 1, 2 * f.dst) :: πe
  for σ in streams, j in [0:streams.size] do
    let (rd, ps, pl, xf) := (base + 4 * j, base + 4 * j + 1, base + 4 * j + 2, base + 4 * j + 3)
    for g in σ.puts do
      πe := (2 * g.ev, rd) :: πe
      πe := (if σ.buffered then (ps, 2 * g.ev + 1) else (xf, 2 * g.ev + 1)) :: πe
    if σ.buffered then
      πe := (rd, ps) :: (ps, pl) :: πe
      for (segs, _) in σ.slots do
        for g in segs do πe := (2 * g.ev, pl) :: (pl, 2 * g.ev + 1) :: πe
    else
      πe := (rd, xf) :: πe
      for (segs, _) in σ.slots do
        for g in segs do πe := (2 * g.ev, xf) :: (xf, 2 * g.ev + 1) :: πe
  let some π := topo (base + 4 * streams.size) πe
    | throw "within one time unit, the events and the streams wait for each other in a cycle"
  let ranked := (streams.toList.zipIdx.map fun (σ, j) =>
    { σ with πread := π[base + 4 * j]!, πpush := π[base + 4 * j + 1]!,
             πpull := π[base + 4 * j + 2]!, πxfer := π[base + 4 * j + 3]! }).toArray
  return { D0 with πs := (List.range nv).toArray.map (π[2 * ·]!),
                   πf := (List.range nv).toArray.map (π[2 * · + 1]!), streams := ranked }

/-- The first part of the certificate the check rejects, for the report. -/
def failure (D : DCert) : String := Id.run do
  for v in [0:D.T.loops.size] do
    if !D.evOk v then return s!"template event {v}'s offsets or ranks"
  for f in D.T.edges do
    if !D.edgeOk f then
      return s!"the edge from template event {f.src} to {f.dst}; classes in order {D.order}, \
        loops {D.loopsOf f.src} and {D.loopsOf f.dst} in classes \
        {(D.loopsOf f.src).map (D.cls[·]!)} and {(D.loopsOf f.dst).map (D.cls[·]!)}, \
        after {D.top[f.src]?.getD []} and {D.top[f.dst]?.getD []}"
  for σ in D.streams, j in [0:D.streams.size] do
    if !D.shapeOk σ then return s!"stream {j}'s shape (from template event {σ.head})"
    if !D.rankOk σ then return s!"stream {j}'s ranks (from template event {σ.head})"
  return "nothing"

end LoopDeadGen

end

end Veir.Air
