// D14b: an explicit pattern (sizes and strides given) on a view whose element 0 lies at position 0
// of its buffer addresses the buffer as on the buffer itself, as AIR's canonicalizer folds it
// (ComposeMemrefOp). A pattern on a view at another offset stays refused (D14 open).

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d14b_view_pattern.mlir 2>/dev/null | filecheck %s
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d14b_view_pattern.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d14b_offset_view.mlir 2>&1 | filecheck %s --check-prefix=OFFSET

// [0] [4] [2] on collapse_shape(src): src[0], src[2], src[4], src[6].
// CHECK: @collapsed: %arg0 = [0..7], %arg1 = [0, 2, 4, 6]
// [0, 1] [2, 2] [4, 1] on a rank-reducing subview at offset 0: positions 1, 2, 5, 6 of src.
// CHECK: @rank_reduced: %arg0 = [0..7], %arg1 = [1, 2, 5, 6]

// RACES-COUNT-2: no deadlock (proven, Chan.checkH_true)

// OFFSET: a DMA on a view with a pattern is not supported (D14, AIR-009)
