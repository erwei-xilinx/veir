// Layer 2: buffers, DMAs and races (SEMANTICS.md D14-D23).

// AIR-007, end to end: the input is race-free (synchronous DMAs, D24), air-dependency's real
// output has an unordered RAW on the L2 buffer;
// running both schedules shows the consequence; with the edge added there is no race.
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/air007_before_air_dependency.mlir | filecheck %s --check-prefix=A7IN
// A7IN:    @f: 2 event(s), 3 buffer(s), 0 race(s), 0 problem(s) inside single events
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/air007_after_air_dependency.mlir | filecheck %s --check-prefix=A7
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/air007_after_air_dependency.mlir | filecheck %s --check-prefix=SCHED
// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/air007_fixed.mlir | filecheck %s --check-prefix=A7FIX
// A7:      @f: 3 event(s), 3 buffer(s), 1 race(s)
// A7-NEXT: race: RAW on alloc in event 0 element 16 between event 1 (air.dma_memcpy_nd) and event 2 (air.dma_memcpy_nd), with no token path between them
// SCHED:   2 finishing order(s) allowed, 2 distinct outcome(s)
// SCHED:   order [0, 1, 2]: {{.*}}%arg1 = [16 : i32, 17 : i32, 18 : i32, 19 : i32, 20 : i32, 21 : i32, 22 : i32, 23 : i32]
// SCHED:   order [0, 2, 1]: {{.*}}%arg1 = [undef, undef, undef, undef, undef, undef, undef, undef]
// A7FIX:   @f: 3 event(s), 3 buffer(s), 0 race(s), 0 problem(s) inside single events

// The cases in Inputs/layer2_cases.air.mlir.src.
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=RACES
// RUN: not air-veir races --allow-unregistered-dialect --args=4 %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=ARGS
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @stride0_dst: 1 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @padding: 1 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @overlap_down: 1 event(s), 1 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @overlap_up: 1 event(s), 1 buffer(s), 0 race(s), 1 problem(s)
// RACES-NEXT:  event 0: race inside air.dma_memcpy_nd on %arg0: element 1 is read at step 1, after it may already be written at step 0 (D21)
// RACES-LABEL: @count_mismatch:
// RACES-NEXT:  event 0: invalid air.dma_memcpy_nd: the source stream has 4 element(s) but the destination pattern 8 (D20)
// RACES-LABEL: @out_of_bounds:
// RACES-NEXT:  event 0: air.dma_memcpy_nd reads out of bounds: position 4 is outside %arg0 (4 elements)
// RACES-LABEL: @dynamic: 2 event(s), 2 buffer(s), 1 race(s)
// RACES-NEXT:  race: WAW on %arg1 element 0 between event 0 (air.dma_memcpy_nd) and event 1 (air.dma_memcpy_nd)
// RACES-LABEL: @linalg: 2 event(s), 2 buffer(s), 1 race(s)
// RACES-NEXT:  race: RAW on %arg0 element 0 between event 0 (air.execute) and event 1 (air.dma_memcpy_nd)
// RACES-LABEL: @dealloc_race: 3 event(s), 2 buffer(s), 1 race(s)
// RACES-NEXT:  race: WAR on alloc in event 0 element 0 between event 1 (air.dma_memcpy_nd) and event 2 (air.execute)
// RACES-LABEL: @load_store: 2 event(s), 1 buffer(s), 0 race(s), 0 problem(s)

// With %off = 4 the two writes of @dynamic are disjoint (D23).
// ARGS: @dynamic: 2 event(s), 2 buffer(s), 0 race(s), 0 problem(s)

// INTERP-LABEL: @stride0_dst: program order: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [3 : i32]
// INTERP-LABEL: @padding: program order: %arg0 = [0 : i32, 1 : i32], %arg1 = [0 : i32, 0 : i32, 1 : i32, 0 : i32]
// INTERP-LABEL: @overlap_down: program order: %arg0 = [1 : i32, 2 : i32, 3 : i32, 3 : i32]
// INTERP-LABEL: @count_mismatch: program order: fault: event 0 (air.dma_memcpy_nd): the source stream has 4 element(s) but the destination pattern 8 (D20)
// INTERP-LABEL: @out_of_bounds: program order: fault: event 0 (air.dma_memcpy_nd): position 4 is outside %arg0 (4 elements)
// INTERP-LABEL: @dynamic: program order:
// INTERP-NEXT:  2 finishing order(s) allowed, 2 distinct outcome(s)
// INTERP-LABEL: @dealloc_race: program order:
// INTERP-NEXT:  2 finishing order(s) allowed, 2 distinct outcome(s)
// INTERP:       fault: event 1 (air.dma_memcpy_nd): a buffer it uses was deallocated
// INTERP-LABEL: @load_store: program order: event 1 = [7 : i32], %arg0 = [0 : i32, 7 : i32]
// INTERP-NEXT:  1 finishing order(s) allowed, 1 distinct outcome(s)
