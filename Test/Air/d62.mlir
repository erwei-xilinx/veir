// D62: offsets, sizes and strides of a transfer that events compute are instantiated with the
// values the execution computes (rounds, as D59), and the transfer reads those results as it
// starts; Chan.decision_reads proves every execution reads the same values. Before D62 such a
// transfer touched its whole buffer.

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d62_offsets.mlir 2>/dev/null | filecheck %s
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d62_offsets.mlir 2>/dev/null | filecheck %s --check-prefix=RACES

// CHECK: @offset_from_execute: %arg0 = [0..7], %arg1 = [4..7]
// CHECK: @two_halves: %arg0 = [0..7], %arg1 = [0..7]

// RACES-LABEL: @offset_from_execute: {{.*}} 0 race(s)
// RACES-NEXT: 1 transfer value(s) (D62){{.*}}(proven, Chan.decision_reads)
// The two halves, at offsets 0 and 4, no longer race.
// RACES-LABEL: @two_halves: {{.*}} 0 race(s)
// RACES-NEXT: 2 transfer value(s) (D62){{.*}}(proven, Chan.decision_reads)
