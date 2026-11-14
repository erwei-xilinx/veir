// Symmetric memory (one buffer per rank, created as a family), cross-rank DMAs (src_rank /
// dst_rank address that rank's buffer), air.translate and air.custom (SEMANTICS.md D49).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/ranks.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/ranks.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/refuse_symmetric_outside_rank.mlir 2>&1 | filecheck %s --check-prefix=OUTSIDE
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/refuse_translate_wrong_from.mlir 2>&1 | filecheck %s --check-prefix=FROM
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/refuse_src_rank_out_of_range.mlir 2>&1 | filecheck %s --check-prefix=RANGE

// RACES-LABEL: @signalled_read: 6 event(s), 6 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @unsignalled_read: 4 event(s), 4 buffer(s), 1 race(s)
// RACES-NEXT:  race: RAW on host alloc (iteration [0]) (symmetric, rank 0) element 0 between event 1 (iteration [0]) (air.dma_memcpy_nd (blocking)) and event 2 (iteration [1]) (air.dma_memcpy_nd (blocking))
// RACES-LABEL: @translate_read: 6 event(s), 7 buffer(s), 0 race(s)
// RACES-LABEL: @custom_ordered: 2 event(s), 2 buffer(s), 0 race(s)
// RACES-LABEL: @custom_unordered: 2 event(s), 2 buffer(s), 1 race(s)

// INTERP-LABEL: @signalled_read: a schedule: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @unsignalled_read:
// INTERP-NEXT:  2 distinct outcome(s)
// INTERP-LABEL: @translate_read: a schedule: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-LABEL: @custom_unordered:
// INTERP-NEXT:  2 distinct outcome(s)

// OUTSIDE: symmetric memory needs an enclosing air.rank (D49)
// FROM: the source is rank 0's buffer, not rank 1's (undefined, D49)
// RANGE: rank 5 is outside the air.rank's 2 rank(s)
