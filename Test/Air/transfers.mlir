// Layer 4: memory ordered by a transfer itself (SEMANTICS.md D36). A put and the get it feeds need
// no token between them (D30: one would deadlock them, AIR-011); a location may be read and
// written within the transfer as long as it is read no later in the stream than it is written.

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer4_transfers.mlir | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer4_transfers.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @same_place: 2 event(s), 1 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @shift_down: 2 event(s), 1 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @shift_up: 2 event(s), 1 buffer(s), 1 race(s)
// RACES-NEXT:  no deadlock
// RACES-NEXT:  race inside the transfer from event 0 to event 1 on @C[]: %arg0 element 1 is read at stream step 1, after it may already be written at step 0 (D36(a))
// RACES-LABEL: @reuse_after_get: 3 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @reuse_unordered: 3 event(s), 3 buffer(s), 1 race(s)
// RACES:       race: RAW on %arg0 element 0 between event 2 (air.dma_memcpy_nd) and the transfer from event 0 (air.channel.put) to event 1, with no token path between them

// INTERP-LABEL: @same_place: a schedule: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @shift_down: a schedule: %arg0 = [1 : i32, 2 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @reuse_after_get:
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @reuse_unordered:
// INTERP-NEXT:  2 distinct outcome(s)
