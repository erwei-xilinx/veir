// Decision D56: each air.launch instance has its own streams; instances run in parallel and do not
// communicate (D37). Lowering a launch to one scf.for of instances is an implementation of it.

// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d56_per_instance.mlir 2>/dev/null | filecheck %s
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/d56_per_instance.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP

// CHECK-LABEL: @per_instance: 18 event(s), 4 buffer(s), 0 race(s)
// CHECK-NEXT:  no deadlock (proven, Chan.checkH_true)

// INTERP: @per_instance: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32], %arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-NEXT: race-free
