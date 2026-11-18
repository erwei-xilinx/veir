// D63: an unranked memref (`memref<*xT>`) is a bare pointer: no upper bound, its extent is how far
// its accesses reach. Before D63 it was read as one element, and every access past position 0 was
// reported out of bounds.

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d63_bare_pointer.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d63_bare_pointer.mlir 2>/dev/null | filecheck %s

// RACES: @offset_past_one: {{.*}} 0 race(s), 0 problem(s)
// RACES: @cast_to_shape: {{.*}} 0 race(s), 0 problem(s)
// RACES: @whole_pointer: {{.*}} 1 problem(s)
// RACES: a bare pointer (unranked memref, D63) as a whole transfer end has no length

// CHECK: @offset_past_one: %arg0 = [0..103], %arg1 = [100..103]
// CHECK: @cast_to_shape: %arg0 = [0..3], %arg1 = [0..3]
// CHECK: @whole_pointer: fault: {{.*}} has no length
