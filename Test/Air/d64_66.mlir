// D64 (`dest` without broadcast_shape), D65 (short offsets padded in front), D66 (a blocking wait
// that begins an air.execute's body). The cases are in Inputs/d64_66.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d64_66.mlir 2>/dev/null | filecheck %s
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d64_66.mlir 2>&1 >/dev/null | filecheck %s --check-prefix=ERR
//
// CHECK: @short_offsets: 4 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// CHECK-NEXT: no deadlock
// CHECK: @wait_in_execute: 5 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// CHECK-NEXT: no deadlock
// CHECK: @dest_zero: 4 event(s), 2 buffer(s), 0 race(s)
// CHECK-NEXT: no deadlock
// ERR: error: @dest_one: @c: `dest` = 1 on a channel without broadcast_shape; only 0 names its one consumer (D64)
