// Layer 3: loops, instantiated iteration by iteration (SEMANTICS.md D26, D27).

// RUN: not air-veir races --allow-unregistered-dialect --args=3 %S/Inputs/layer3_loops.mlir 2>&1 | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect --max-orders=2000 %S/Inputs/layer3_loops.mlir 2>&1 | filecheck %s --check-prefix=INTERP
// RUN: air-veir graph --allow-unregistered-dialect --args=3 %S/Inputs/layer3_loops.mlir 2>&1 | filecheck %s --check-prefix=GRAPH
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer3_loops.mlir 2>&1 | filecheck %s --check-prefix=NOARGS
// RUN: not air-veir reduce --allow-unregistered-dialect --args=3 %S/Inputs/layer3_loops.mlir 2>&1 | filecheck %s --check-prefix=REDUCE

// A one-chain pipeline: race-free, one outcome.
// RACES-LABEL: @chain: 9 event(s), 3 buffer(s), 0 race(s), 0 problem(s)
// The load does not wait for the previous iteration: iterations race on %buf.
// RACES-LABEL: @chain_broken: 9 event(s), 3 buffer(s), 12 race(s)
// RACES-NEXT:  race: WAW on alloc in event 0 element 0 between event 1 (iteration [0]) (air.dma_memcpy_nd) and event 3 (iteration [1]) (air.dma_memcpy_nd), with no token path between them
// RACES-NEXT:  race: WAR on alloc in event 0 element 0 between event 2 (iteration [0]) (air.dma_memcpy_nd) and event 3 (iteration [1]) (air.dma_memcpy_nd), with no token path between them
// Ping-pong with one chain per buffer: race-free.
// RACES-LABEL: @ping_pong: 10 event(s), 4 buffer(s), 0 race(s), 0 problem(s)
// scf.parallel: disjoint tiles do not race, overlapping ones do.
// RACES-LABEL: @parallel_tiles: 10 event(s), 3 buffer(s), 0 race(s), 0 problem(s)
// RACES-LABEL: @parallel_overlap: 7 event(s), 2 buffer(s), 2 race(s)
// RACES-NEXT:  race: WAW on %arg1 element 2 between event 1 (iteration [0]) (air.dma_memcpy_nd) and event 2 (iteration [2]) (air.dma_memcpy_nd)
// RACES-LABEL: @dynamic_trips: 4 event(s), 0 buffer(s), 0 race(s), 0 problem(s)

// INTERP-LABEL: @chain: program order: {{.*}}%arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-NEXT:  1 finishing order(s) allowed, 1 distinct outcome(s)
// INTERP-LABEL: @chain_broken: program order:
// INTERP-NEXT:  105 finishing order(s) allowed, 37 distinct outcome(s)
// INTERP-LABEL: @ping_pong: program order:
// INTERP-NEXT:  252 finishing order(s) allowed, 1 distinct outcome(s)
// INTERP-LABEL: @parallel_tiles: program order: {{.*}}%arg2 = [0 : i32, 1 : i32, 2 : i32, 3 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-NEXT:  105 finishing order(s) allowed, 1 distinct outcome(s)

// GRAPH-LABEL: @dynamic_trips: 4 event(s)
// GRAPH-NEXT:  event 0: air.wait_all async waits for [], keeps []
// GRAPH-NEXT:  event 1 (iteration [0]): air.wait_all async waits for [0], keeps [0]
// GRAPH-NEXT:  event 2 (iteration [1]): air.wait_all async waits for [1], keeps [1]
// GRAPH-NEXT:  event 3 (iteration [2]): air.wait_all async waits for [2], keeps [2]

// NOARGS: @dynamic_trips: scf.for: a loop bound is not known (does it depend on an argument? pass --args)
// REDUCE: reduce does not support loops yet; check can validate another tool's rewrite
