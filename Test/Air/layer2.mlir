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
// A7-NEXT: no deadlock
// A7-NEXT: race: RAW on alloc in event 0 element 16 between the transfer of element 8 of event 1 (air.dma_memcpy_nd) and the read of element 0 of event 2 (air.dma_memcpy_nd)
// SCHED:   @f: {{.*}}%arg1 = [16 : i32, 17 : i32, 18 : i32, 19 : i32, 20 : i32, 21 : i32, 22 : i32, 23 : i32]
// SCHED-NEXT: races (see `races`); an execution with the read of element 0 of event 2 (air.dma_memcpy_nd) before the transfer of element 8 of event 1 (air.dma_memcpy_nd) ends differently: {{.*}}%arg1 = [undef, 17 : i32, 18 : i32, 19 : i32, 20 : i32, 21 : i32, 22 : i32, 23 : i32]
// A7FIX:   @f: 3 event(s), 3 buffer(s), 0 race(s), 0 problem(s) inside single events

// The cases in Inputs/layer2_cases.air.mlir.src.
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=RACES
// RUN: not air-veir races --allow-unregistered-dialect --args=4 %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=ARGS
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer2_cases.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @stride0_dst: 1 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @padding: 1 event(s), 2 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @overlap_down: 1 event(s), 1 buffer(s), 0 race(s), 0 problem(s)
// D21 is not checked on its own: the reads of a DMA may run ahead of its writes in the model.
// RACES-LABEL: @overlap_up: 1 event(s), 1 buffer(s), 1 race(s), 0 problem(s)
// RACES-NEXT:  no deadlock
// RACES-NEXT:  race: RAW on %arg0 element 1 between the transfer of element 0 of event 0 (air.dma_memcpy_nd) and the read of element 1 of event 0 (air.dma_memcpy_nd)
// RACES-LABEL: @count_mismatch:
// RACES:       event 0: invalid air.dma_memcpy_nd: the source stream has 4 element(s) but the destination pattern 8 (D20)
// RACES-LABEL: @out_of_bounds:
// RACES:       event 0: air.dma_memcpy_nd reads out of bounds: position 4 is outside %arg0 (4 elements)
// RACES-LABEL: @dynamic: 2 event(s), 2 buffer(s), 1 race(s)
// RACES:       race: WAW on %arg1 element {{[0-9]+}} between {{.*}}event 0 (air.dma_memcpy_nd) and {{.*}}event 1 (air.dma_memcpy_nd)
// RACES-LABEL: @linalg: 2 event(s), 2 buffer(s), 1 race(s)
// RACES:       race: RAW on %arg0 element {{[0-9]+}} between finish of event 0 (air.execute) and the read of element {{[0-9]+}} of event 1 (air.dma_memcpy_nd)
// RACES-LABEL: @dealloc_race: 3 event(s), 2 buffer(s), 1 race(s)
// RACES:       race: WAR on alloc in event 0 element {{[0-9]+}} between the read of element {{[0-9]+}} of event 1 (air.dma_memcpy_nd) and finish of event 2 (air.execute)
// RACES-LABEL: @load_store: 2 event(s), 1 buffer(s), 0 race(s), 0 problem(s)

// With %off = 4 the two writes of @dynamic are disjoint (D23).
// ARGS: @dynamic: 2 event(s), 2 buffer(s), 0 race(s), 0 problem(s)

// INTERP-LABEL: @stride0_dst: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [3 : i32]
// INTERP-LABEL: @padding: %arg0 = [0 : i32, 1 : i32], %arg1 = [0 : i32, 0 : i32, 1 : i32, 0 : i32]
// INTERP-LABEL: @overlap_down: %arg0 = [1 : i32, 2 : i32, 3 : i32, 3 : i32]
// INTERP-LABEL: @count_mismatch: fault: event 0 (air.dma_memcpy_nd): the source stream has 4 element(s) but the destination pattern 8 (D20)
// INTERP-LABEL: @out_of_bounds: fault: event 0 (air.dma_memcpy_nd): position 4 is outside %arg0 (4 elements)
// INTERP-LABEL: @dynamic:
// INTERP-NEXT:  races (see `races`); an execution with {{.*}} ends differently
// INTERP-LABEL: @dealloc_race:
// INTERP-NEXT:  races (see `races`); an execution with {{.*}} ends differently: fault: {{.*}}a buffer it uses was deallocated
// INTERP-LABEL: @load_store: event 1 = [7 : i32], %arg0 = [0 : i32, 7 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
