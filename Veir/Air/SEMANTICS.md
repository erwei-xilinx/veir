# AIR semantic decisions

Every choice about what an AIR construct *means* is recorded here, with its status. A theorem is
only as good as the model it is about, and the model is only as good as these decisions. They are
made by the AIR developers, not inferred from the code alone.

Status: ✅ confirmed by an AIR developer · ❓ pending confirmation · ❌ rejected (the old reading
is wrong; the replacement is pending or recorded).

| # | Decision | Status | Where encoded | Theorems that depend on it |
| --- | --- | --- | --- | --- |
| D1 | Blocking `air.wait_all` | ✅ 2026-11-13 | `EventKind.waitAllBlocking`, `Event.implicitDeps` | `steps_between_iff` (applied to the AIR rewrite) |
| D2 | `air.wait_all async` does not block | ✅ 2026-11-13 | `EventKind.waitAll` | — |
| D3 | Unordered async ops may run in any order and overlap | ✅ 2026-11-13 | `Ready`, `Step` | all trace theorems |
| D4 | A value is ordered by a token path, direct or transitive; with no path, the program is wrong | ✅ 2026-11-13 | `Program.finishEvent` (fault), `Program.unorderedReads` | `Program.steps_reduce_iff` |
| D5 | `func.return` does not wait for outstanding events | ✅ 2026-11-13 | `func.return` is not an event | none yet |
| D6 | Conflicting memory accesses (RAW, WAR, WAW) must be ordered by tokens | ✅ 2026-11-13 | not encoded (memory not modelled) | none yet |
| D7 | Effects of an `air.execute` take place at its finish | ❓ awaits the proof described below; no question for the AIR developers | `Sem`, `Program.sem` | `Program.steps_reduce_iff` |
| D8 | Terminator/result mismatch is an AIR verifier bug | ✅ 2026-11-13 | `executeBody` refuses it | — |
| D9 | `!air.token` and affinity/concurrency lists are planned | ✅ 2026-11-13 | not encoded | — |
| D10 | `air-dependency-canonicalize` is an exact transitive reduction | ✅ 2026-11-13 | `DepGraph.reduce` | `reach_reduce_iff`, `steps_reduce_iff` |
| D11 | Function-level `arith.constant` runs before any event | not a semantic choice | `Program.initState` | — |

## D1. Blocking `air.wait_all` ✅

`air.wait_all` without `async` (and so without a result) blocks the host until its dependencies are
done. Nothing after it is issued before that, so every later event waits for it although no operand
says so.

```mlir
air.wait_all [%a]
%b = air.execute { ... }   // waits for %a, through the blocking wait
```

## D2. `air.wait_all async` ✅

`air.wait_all async [...]` does not block. It is an event that completes once its dependencies are
done.

## D3. Unordered async ops ✅

Two async ops with no token path between them may run in either order and may overlap. Having
its dependencies met allows an op to start; it does not force it to.

## D4. Using a value requires a token path ✅

A use of an `air.execute` result need not name that execute's token directly. The canonicalizer
removes the direct edge when an intermediate op already orders the two:

```mlir
%t, %v = air.execute -> (i32) { ... }
%m = air.execute [%t] { use %v }     // depends on %t
%u = air.execute [%m] { use %v }     // uses %v; ordered after %t through %m
```

There must be a token path, direct or transitive, from the producer to every user. A program
without one is wrong: the `air-dependency` pass should have created the path. The model reports
that program as a data race: `air-veir graph` warns, and any schedule that runs the user first
faults. Since the reduction preserves reachability (`reach_reduce_iff`), it can never create such
a race.

## D5. `func.return` does not wait ✅

A function may return while events it issued are still outstanding. Returning a token hands the
wait to the caller:

```mlir
func.func @wait() -> !air.async.token {
  %e = air.wait_all async [...]
  return %e : !air.async.token    // does not wait for %e
}
```

`func.return` is not an event, and a complete trace runs every event to completion. Once calls
are modelled, the caller will see the returned token as a dependency it may wait for.

(History: this reading was first questioned, then confirmed the same day.)

## D6. Memory conflicts must be ordered ✅

When several `air.execute`s (and later DMAs) access the same memory, the `air-dependency` pass is
responsible for adding token edges, direct or transitive, that order every RAW, WAR and WAW pair
of accesses. Reads after reads need no ordering. This matches
`mlir/lib/Transform/AIRDependency.cpp`, which detects RAW and WAW/WAR (lines 255–291). A conflict
left unordered is a program error.

**Consequence for the model, once memory is added.** An unordered conflict will be a race,
reported as a fault, not given a meaning. For race-free programs, non-conflicting bodies commute,
so how event bodies interleave cannot change the result. That is what makes D7 safe.

## D7. Effects of an `air.execute` take place at its finish ❓ (awaits a proof)

The model applies a body's effects atomically when the event finishes. For pure `arith` bodies
this is unobservable. With memory, D6 makes it sound: in a race-free program, two bodies that may
run at the same time access no memory in conflict, so any interleaving of their steps has the
same effect as running one and then the other. This needs no further input from the AIR
developers. It becomes ✅ when the memory model is added and that commutation argument is proven:
fine-grained interleavings of race-free programs equal atomic ones.

## D8. Terminator/result mismatch is a bug ✅

`air.execute -> (index)` whose terminator yields an `i32`, or yields nothing, is accepted by
`ExecuteOp::verify`. That is a verifier bug. VeIR's structure check mirrors AIR's for now, and
`extract` refuses the op.

## D9. `!air.token` and affinity/concurrency lists are planned ✅

`docs/AIRComputeModel.md`'s `!air.token`, `air.token.alloc` and the three token lists
(`dependency`, `affinity`, `concurrency`) are planned. The model must leave room for them:
- **`dependency`** is the ordering modelled now (`Reach`).
- **`affinity`** is a constraint on resources. It implies disjoint lifetimes, so at least
  "not overlapping".
- **`concurrency`** requires overlapping lifetimes. That is a *liveness* requirement, which the
  current model can state (`start`/`finish` labels give lifetimes) but does not yet constrain.
  Note that it can deadlock with dependencies, and with resources.

## D10. `air-dependency-canonicalize` is an exact transitive reduction ✅

The pass computes the minimal dependency graph: it removes exactly the edges implied by other
paths, and no others. An output that also dropped an edge not implied by another path would be a
bug, and `air-veir check` rejects it.

## D11. Function-level constants

`arith.constant` in the function body is evaluated before any event. It is pure, so when it runs
cannot be observed. This is a modelling convenience, not a semantic decision.
