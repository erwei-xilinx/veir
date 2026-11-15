// Layer 4: memory ordered by a transfer itself (SEMANTICS.md D36). A put and the get it feeds need
// no token between them (D30: one would deadlock them, AIR-011); a location may be read and
// written within the transfer as long as it is read no later in the stream than it is written.
// D36 is not assumed: it follows from the element semantics (Veir.Air.ChanSem, ChanMem).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer4_transfers.mlir | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer4_transfers.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @same_place: 2 event(s), 1 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @shift_down: 2 event(s), 1 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @shift_up: 2 event(s), 1 buffer(s), 1 race(s)
// RACES-NEXT:  no deadlock
// RACES-NEXT:  race: RAW on %arg0 element 1 between the transfer of element 0 of @C[] and the read of element 1 of @C[]
// RACES-LABEL: @reuse_after_get: 3 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @reuse_unordered: 3 event(s), 3 buffer(s), 4 race(s)
// RACES:       race: RAW on %arg0 element 0 between finish of event 2 (air.dma_memcpy_nd) and the read of element 0 of @C[]

// INTERP-LABEL: @same_place: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @shift_down: %arg0 = [1 : i32, 2 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @reuse_after_get:
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @reuse_unordered:
// INTERP-NEXT:  races (see `races`)
