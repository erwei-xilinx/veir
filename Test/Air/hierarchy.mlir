// Layer 5: air.launch / air.segment / air.herd / air.rank (SEMANTICS.md D37-D44). Each op is a
// start event, its body once per instance, and an end event (its token) that waits for every
// event inside (D38).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer5_hierarchy.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer5_hierarchy.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP

// mlir-air's channel_drain_hierarchy.mlir after air-dependency deadlocks (AIR-012).
// RACES-LABEL: @drain_dep: 12 event(s)
// RACES-NEXT:  DEADLOCK: no schedule exists; stuck (checked by stuckB): finish of event 6 {{.*}}(air.channel.put), {{.*}}(end of a hierarchy op){{.*}}(air.channel.get)
// RACES-LABEL: @drain_fixed: 12 event(s), 3 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @herd_tiles: 18 event(s), 6 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @herd_shared_write: 6 event(s), 2 buffer(s), 6 race(s)
// RACES-NEXT:  race: WAW on %arg0 element 0 between event 1 (iteration [0, 0]) (air.dma_memcpy_nd) and event 2 (iteration [0, 1]) (air.dma_memcpy_nd), with no token path between them
// RACES-LABEL: @sync_herd: 4 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @async_herd_unordered: 4 event(s), 3 buffer(s), 1 race(s)
// RACES-NEXT:  race: RAW on %arg0 element 0 between event 1 (iteration [0, 0]) (air.dma_memcpy_nd) and event 3 (air.dma_memcpy_nd)
// RACES-LABEL: @token_arg: 4 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @launch_talk:
// RACES-NEXT:  error: @L[1]: event 1's put feeds event 4's get across two instances of one air.launch ([0] and [1]), which may run one after another (D37)
// RACES-NEXT:  error: @L[0]: event 3's put feeds event 2's get across two instances of one air.launch ([1] and [0]), which may run one after another (D37)
// RACES-LABEL: @nested_segment: 6 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @rank_talk: 6 event(s), 2 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock

// INTERP-LABEL: @drain_dep: deadlocks
// INTERP-LABEL: @drain_fixed: a schedule: {{.*}}%arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32], %arg1 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @herd_tiles: a schedule: {{.*}}%arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @sync_herd: {{.*}}%arg2 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  1 finishing order(s) allowed, 1 distinct outcome(s)
// INTERP-LABEL: @async_herd_unordered:
// INTERP-NEXT:  2 distinct outcome(s)
// INTERP-LABEL: @token_arg:
// INTERP-NEXT:  1 distinct outcome(s)
// INTERP-LABEL: @rank_talk: a schedule: %arg0 = [1001 : i32, 1000 : i32, 2 : i32, 3 : i32]
