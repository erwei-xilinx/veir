// Ops without `async` (memref.dealloc, func.call, linalg.*, ...) are blocking events in program
// order (SEMANTICS.md D45). So the input of air-dependency can be checked, not only its output.

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/sync_ops.mlir 2>/dev/null | filecheck %s --check-prefix=IN
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/sync_ops.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/sync_ops_after_air_dependency.mlir 2>/dev/null | filecheck %s --check-prefix=OUT

// IN-LABEL: @use_after_dealloc: 2 event(s)
// IN-LABEL: @call_then_dma: 2 event(s), 2 buffer(s), 0 race(s)
// A sync op blocks what follows it, not what came before (D25).
// IN-LABEL: @dma_then_call: 2 event(s), 2 buffer(s), 1 race(s)
// IN-NEXT:  race: WAR on %arg0 element 0 between event 0 (air.dma_memcpy_nd) and event 1 (a synchronous op), with no token path between them
// IN-LABEL: @sync_herd_body: 5 event(s), 2 buffer(s), 0 race(s)
// IN-NEXT:  no deadlock
// IN-LABEL: @fifo_before_loop: 21 event(s), 2 buffer(s), 0 race(s)
// IN-NEXT:  no deadlock

// INTERP-LABEL: @use_after_dealloc: program order: fault: event 1 (air.dma_memcpy_nd): a buffer it uses was deallocated
// INTERP-LABEL: @dma_then_call:
// INTERP-NEXT:  2 distinct outcome(s)

// air-dependency orders the DMA before the call, but loses the order of the put before the loop
// (AIR-014).
// OUT-LABEL: @dma_then_call: 2 event(s), 2 buffer(s), 0 race(s)
// OUT-LABEL: @fifo_before_loop:
// OUT-NEXT:  error: channel order race (D33): two puts on @C[0, 0] (events 0 and 2) with no token path between them
