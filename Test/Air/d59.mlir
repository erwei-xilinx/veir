// D59, D60: control flow decided by values events compute, followed for the input given.

// RUN: not air-veir races --allow-unregistered-dialect --mem=0:3 %S/Inputs/d59_device_bound.mlir | filecheck %s
// CHECK-LABEL: @device_bound: 6 event(s), 2 buffer(s), 0 race(s)
// CHECK-NEXT: 'scf.for' (event 0 = 3). Every execution reads these values (proven, Chan.decision_reads)
// CHECK-NEXT: no deadlock (proven
// No token path from the execute to the loop: the decision's read is a race (D60).
// CHECK-LABEL: @unordered_bound: 5 event(s), 2 buffer(s), 1 race(s)
// CHECK-NEXT: not established (the program has a race)
// CHECK: race: RAW on the results of an event element 0 between finish of event 0 (air.execute) and finish of event 1 (control-flow decision)
// CHECK-LABEL: @device_branch:
// CHECK-NEXT: 'scf.if' (event 0 = 0). Every execution reads these values (proven, Chan.decision_reads)
// The bound reaches the core through a channel; the herd's loop is instantiated once it arrived.
// CHECK-LABEL: @channel_bound:
// CHECK-NEXT: 'scf.for' (iteration [0, 0, 0, 0]) (event 4 = 3). Every execution reads these values (proven, Chan.decision_reads)
// CHECK-NEXT: no deadlock (proven

// RUN: air-veir run --allow-unregistered-dialect --mem=0:3 %S/Inputs/d59_device_bound.mlir | filecheck %s --check-prefix=INTERP
// INTERP: @device_bound: event 0 = [3 : i64], %arg0 = [3 : i32], %arg1 = [7 : i32, 7 : i32, 7 : i32, 1003 : i32
// INTERP: @device_branch: event 0 = [0 : i1], %arg0 = [3 : i32], %arg1 = [7 : i32, 1001 : i32
// INTERP: @channel_bound: event 4 = [3 : i64], %arg0 = [3 : i32], %arg1 = [7 : i32, 7 : i32, 7 : i32, undef, undef

// The same input from a file, and another value.
// RUN: air-veir outcome --allow-unregistered-dialect --mem=0@%S/Inputs/d59_bound.txt %S/Inputs/d59_device_bound.mlir | filecheck %s --check-prefix=FILE
// FILE: @device_bound: fault: event 11 (iteration [8]): memref.store: index 8 is outside a dimension of size 8
// FILE: @device_branch: %arg0 = [9], %arg1 = [9, 1001..1007]

// The synchronous program is fine; air-dependency leaves the index_cast unordered after the load
// (AIR-024), so the value deciding the loop is not computed in the part before it, which races.
// RUN: air-veir races --allow-unregistered-dialect --mem=0:3 %S/Inputs/d59_sync_bound.mlir | filecheck %s --check-prefix=SYNC
// SYNC: 'scf.for' (event 1 = 3). Every execution reads these values (proven, Chan.decision_reads)
// RUN: not air-veir races --allow-unregistered-dialect --mem=0:3 %S/Inputs/d59_sync_bound_dep.mlir | filecheck %s --check-prefix=DEP
// DEP: the value deciding 'scf.for' is not computed in the execution proposed for the part of the program before it
// DEP: race: RAW on the results of an event element 0 between finish of event 0 (air.execute) and finish of event 1 (a synchronous op)

// Wrong input sizes are refused.
// RUN: not air-veir races --allow-unregistered-dialect --mem=0:1,2 %S/Inputs/d59_device_bound.mlir 2>&1 | filecheck %s --check-prefix=SIZE
// SIZE: --mem=0: 2 value(s) for 1 element(s)
