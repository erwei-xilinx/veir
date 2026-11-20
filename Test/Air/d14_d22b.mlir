// D14 (a pattern on a view starts at the view's element 0, in elements of its buffer) and D22b
// (linalg ops and memref.copy touch only their operands' elements). The cases are in
// Inputs/d14_d22b.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d14_d22b.mlir 2>/dev/null | filecheck %s
//
// CHECK: @pattern_on_view: 5 event(s), 2 buffer(s), 1 race(s)
// CHECK: race: WAR on host alloc element 11 between the read of element 1 of event 1 (air.dma_memcpy_nd) and finish of event 2 (air.execute)
// CHECK-NOT: element 15
// CHECK: @fills_disjoint: 3 event(s), 1 buffer(s), 0 race(s)
// CHECK: @fills_overlap: 3 event(s), 1 buffer(s), 1 race(s)
// CHECK: race: WAR on host alloc element 8
