// Phase 2b: completion for every trip count of the symbolic loops (LoopDead, LoopDeadGen).
// The cases are in Inputs/loopdead.air.mlir.src. Without --args, the loop bounds are symbolic.
//
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/loopdead.mlir 2>/dev/null | filecheck %s
//
// CHECK: @aligned: {{.*}} race-free for every trip count
// CHECK-NEXT: completes for every trip count (proven, LoopDead.completes_of_deadOk
// CHECK-NEXT: one outcome for every trip count (proven, LoopDead.outcome_every_trip)
// CHECK: @multiple: {{.*}} race-free for every trip count
// CHECK-NEXT: completes for every trip count (proven, LoopDead.completes_of_deadOk
// CHECK-NEXT: one outcome for every trip count (proven, LoopDead.outcome_every_trip)
// CHECK: @gets_after_puts: {{.*}} race-free for every trip count
// CHECK-NEXT: completion for every trip count not established: the ranking does not check
// CHECK: @other_bound: {{.*}} race-free for every trip count
// CHECK-NEXT: completion for every trip count not established: loops [0, 1] are tied by streams, but their trip counts are not the same expression
// CHECK: @unbalanced: {{.*}} race-free for every trip count
// CHECK-NEXT: completion for every trip count not established: a stream's puts and gets do not balance for every trip count
//
// With the trip counts given, the element-level model agrees: the aligned and the multiple
// complete, the gets after the puts and the unbalanced stream deadlock.
// RUN: not air-veir races --allow-unregistered-dialect --args=3,3 %S/Inputs/loopdead.mlir 2>/dev/null | filecheck %s --check-prefix=N3
// N3: @aligned:
// N3-NEXT: no deadlock
// N3: @multiple:
// N3-NEXT: no deadlock
// N3: @gets_after_puts:
// N3-NEXT: DEADLOCK
// N3: @other_bound:
// N3-NEXT: no deadlock
// N3: @unbalanced:
// N3-NEXT: DEADLOCK
