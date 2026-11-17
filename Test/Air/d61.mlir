// Decision D61: air.refeed_count = N on a put is N sends of its pattern, in order, as the loop
// air-annotate-refeed collapsed. The count is the put's own, else its channel's, or the one on the
// memref.alloc of the buffer it sends (an L2 producer). A get is unaffected.

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d61_refeed.mlir 2>/dev/null | filecheck %s
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d61_refeed.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d61_two_puts.mlir 2>&1 | filecheck %s --check-prefix=TWO

// The consumers take N copies in one get each; without the count they would never complete.
// CHECK: @op_count: %arg0 = [0..3], %arg1 = [0..3, 0..3, 0..3]
// CHECK: @decl_count: %arg0 = [0..3], %arg1 = [0..3, 0..3]
// CHECK: @alloc_count: %arg0 = [0..3], %arg1 = [0..3, 0..3]
// CHECK: @get_count: %arg0 = [0..3], %arg1 = [0..3]

// RACES-COUNT-4: no deadlock (proven, Chan.checkH_true)
// RACES-NOT: DEADLOCK

// TWO: carries air.refeed_count = 2 and is sent by more than one put; the count is their sum, and each put's share is unknown (D61)
