// D68 (a dynamic memref argument has the shape it is cast or copied to), D69 (an alloc's dynamic
// sizes as instantiated), D70 (a leading dynamic dimension with no cast is a bare pointer's).
// The cases are in Inputs/d68_70.air.mlir.src and Inputs/d68_cast_small.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d68_70.mlir 2>/dev/null | filecheck %s
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d68_70.mlir 2>&1 >/dev/null | filecheck %s --check-prefix=ERR
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d68_cast_small.mlir 2>&1 | filecheck %s --check-prefix=SMALL
//
// CHECK: @cast_shape: 5 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// CHECK-NEXT: no deadlock
// CHECK: @copy_shape: 3 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// CHECK-NEXT: no deadlock
// CHECK: @leading_dyn: 4 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// CHECK-NEXT: no deadlock
// CHECK: @alloc_known: 4 event(s), 2 buffer(s), 0 race(s)
// CHECK-NEXT: no deadlock
// CHECK: @alloc_arg: transfer sizes depend on the scalar argument(s) %arg0, not given
// CHECK-NOT: not split
// CHECK: @alloc_arg [%arg0 = 3]:
// CHECK-NEXT: DEADLOCK
// CHECK: @alloc_arg: 3 of 3 case(s) not clean (above): not for every value of %arg0
// ERR: error: @whole_leading_dyn: a memref with a leading dynamic dimension (D70) as a whole transfer end has no length
// SMALL: error: @cast_too_small: position 16 is outside %arg0 (16 elements)
