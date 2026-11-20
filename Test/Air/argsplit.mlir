// Branches on scalar arguments not given (ArgSplit): each argument that only comparisons with
// constants read is split into classes of values, one value checked for each; together they cover
// every value. The cases are in Inputs/argsplit.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/argsplit.mlir 2>/dev/null | filecheck %s
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/argsplit.mlir 2>&1 >/dev/null | filecheck %s --check-prefix=ERR
//
// CHECK: @switch_both_sides: branches read the scalar argument(s) %arg0, not given: 5 class(es) of values
// CHECK-SAME: the constants {{\[\[}}0, 1, 2]]
// CHECK: @switch_both_sides [%arg0 = 0]:
// CHECK-NEXT: no deadlock
// CHECK: @switch_both_sides [%arg0 = -1]:
// CHECK-NEXT: no deadlock
// CHECK: @switch_both_sides: every class is clean: for every value of %arg0
// CHECK: @flag: branches read the scalar argument(s) %arg0, not given: 2 class(es)
// CHECK: @flag [%arg0 = -1]:
// CHECK-NEXT: no deadlock
// CHECK: @flag [%arg0 = 0]:
// CHECK-NEXT: no deadlock
// CHECK: @flag: every class is clean: for every value of %arg0
// CHECK: @one_side_guarded: branches read the scalar argument(s) %arg0, not given: 3 class(es)
// CHECK: @one_side_guarded [%arg0 = 4]:
// CHECK-NEXT: DEADLOCK
// CHECK: @one_side_guarded [%arg0 = 3]:
// CHECK-NEXT: no deadlock
// CHECK: @one_side_guarded: 2 of 3 class(es) not clean (above): not for every value of %arg0
// ERR: error: @also_offset: 'scf.if': the branch condition is not known before running
// ERR-SAME: scalar arguments not split (ArgSplit): %arg0: 'air.channel.put' reads it
//
// A value given is not split; `?` leaves one unknown.
// RUN: not air-veir races --allow-unregistered-dialect --args=5 %S/Inputs/argsplit.mlir 2>/dev/null | filecheck %s --check-prefix=GIVEN
// GIVEN: @switch_both_sides: 8 event(s)
// GIVEN: @one_side_guarded: 7 event(s)
// GIVEN-NEXT: DEADLOCK
// RUN: not air-veir races --allow-unregistered-dialect --args=? %S/Inputs/argsplit.mlir 2>/dev/null | filecheck %s --check-prefix=UNKNOWN
// UNKNOWN: @switch_both_sides: branches read the scalar argument(s) %arg0
