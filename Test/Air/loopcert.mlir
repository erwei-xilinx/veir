// Phase 2a (SCALE_DESIGN.md §3.1): a function whose loop bound is not known, or whose loops are
// too large to instantiate, is checked through a loop template; the certificate proves
// race-freedom for every trip count (LoopCert.raceFree_of_certOk), or reports the pair it cannot
// order or separate.

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/loopcert.mlir 2>/dev/null | filecheck %s

// CHECK: @chain: 2 template event(s), 1 symbolic loop(s): race-free for every trip count
// CHECK: @unordered: {{.*}} not established: 'air.execute' and 'air.execute' (loop 0: earlier iteration) are neither ordered nor disjoint
// CHECK: @tiles: 1 template event(s), 1 symbolic loop(s): race-free for every trip count
// CHECK: @tiles_same: {{.*}} not established: 'memref.store' and 'memref.store' (loop 0: earlier iteration)
// CHECK: @big: 2 template event(s), 1 symbolic loop(s): race-free for every trip count
// CHECK: @nest_wrap: 2 template event(s), 2 symbolic loop(s): race-free for every trip count
// CHECK: @nest_unordered: {{.*}} not established: 'air.dma_memcpy_nd' and 'air.dma_memcpy_nd' (loop 0: earlier iteration
