// affine.for as upstream MLIR defines it: the lower bound is the largest result of its map, the
// upper bound the smallest, the step a constant; then iterations in order, as scf.for (D26).
// affine.load and affine.store address the element their map computes from the indices.

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/affine_for.mlir 2>/dev/null | filecheck %s
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/affine_for.mlir 2>/dev/null | filecheck %s --check-prefix=RACES

// i = 0, 2, 4, 6 (max(0, -2) to min(7, 13) step 2) copies src[i + 1]; the rest keep their initial values.
// CHECK: @bounds: %arg0 = [0..7], %arg1 = [1, 1001, 3, 1003, 5, 1005, 7, 1007]
// CHECK: @carried: %arg0 = [0..3], %arg1 = [3, 2, 1, 0]

// RACES-COUNT-2: 0 race(s), 0 problem(s) inside single events
