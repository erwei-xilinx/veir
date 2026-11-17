// D27: the iterations of scf.parallel, scf.forall and affine.parallel are all concurrent. A
// blocking op orders only the rest of its own iteration; after the loop, the host waits for every
// iteration's blocking ops. affine.parallel's bounds are the max/min of each dimension's group.

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/parallel_loops.mlir 2>/dev/null | filecheck %s
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/parallel_loops.mlir 2>/dev/null | filecheck %s --check-prefix=RACES

// Points (0,1), (0,5), (1,1), (1,5) write 100 + their position; the loads after the loop see them.
// CHECK: @forall_disjoint: %arg0 = [0, 101, 2..4, 105, 6..8, 109, 10..12, 113, 14, 15], %arg1 = [101]
// Columns max(0, 1) = 1 to min(8, 5) = 5 step 2: 1 and 3, rows 0 and 1.
// CHECK: @affine_groups: %arg0 = [0, 101, 2, 103, 4..8, 101, 10, 103, 12..31]

// RACES: @forall_disjoint: {{.*}} 0 race(s)
// RACES: @affine_groups: {{.*}} 0 race(s)
// Two iterations store to element 0, with blocking stores: still concurrent, a race.
// RACES: @forall_same: {{.*}} 1 race(s)
// RACES: race: WAW on %arg0 element 0
// RACES: @affine_same: {{.*}} 1 race(s)
// RACES: race: WAW on %arg0 element 0
// RACES: @parallel_same: {{.*}} 1 race(s)
// RACES: race: WAW on %arg0 element 0
