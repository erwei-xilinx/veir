// Views whose element positions are known: a view of a strided view (its source shape is the
// view's, not the layout's), and memref.transpose. The cases are in Inputs/views.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/views.mlir 2>/dev/null | filecheck %s
//
// CHECK: @sub_of_sub: 4 event(s), 2 buffer(s), 1 race(s)
// CHECK: race: WAR on host alloc element 20 between the read of element 0 of event 1 (air.dma_memcpy_nd) and finish of event 2 (air.execute)
// CHECK: @transpose_view: 4 event(s), 2 buffer(s), 1 race(s)
// CHECK: race: WAR on host alloc element 13 between the read of element 7 of event 1 (air.dma_memcpy_nd) and finish of event 2 (air.execute)
