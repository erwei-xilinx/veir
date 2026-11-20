// D22c: bufferization.to_tensor is a snapshot of its buffer, and materialize_in_destination writes
// the tensor into its destination, element by element. The cases are in Inputs/d22c.air.mlir.src.
// Memref arguments start as 1000 * argument + element.
//
// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d22c.mlir 2>/dev/null | filecheck %s
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d22c.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
//
// CHECK: @snapshot: %arg0 = [7, 1..3], %arg1 = [0..3]
// CHECK: @into_view: %arg0 = [0..3], %arg1 = [1000, 1001, 0..3, 1006, 1007]
// RACES-COUNT-2: 0 race(s)
