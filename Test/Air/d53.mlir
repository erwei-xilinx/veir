// Decision D53: a broadcast from an async put meets every get at once (as the hardware does),
// even when some of those gets are sync; a sync put buffers it.

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d53_broadcast.mlir 2>/dev/null | filecheck %s
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/d53_broadcast.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP

// Tile 1's async get waits for tile 0's signal, sent after tile 0's sync get: a cycle.
// CHECK-LABEL: @mixed_signalled:
// CHECK-NEXT:  DEADLOCK (proven, Chan.checkH_false)
// CHECK-LABEL: @mixed_free:
// CHECK-NEXT:  no deadlock (proven, Chan.checkH_true)
// CHECK-LABEL: @sync_put_signalled:
// CHECK-NEXT:  no deadlock (proven, Chan.checkH_true)

// INTERP-LABEL: @mixed_signalled: deadlocks
// INTERP-LABEL: @mixed_free: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  race-free
// INTERP-LABEL: @sync_put_signalled: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  race-free
