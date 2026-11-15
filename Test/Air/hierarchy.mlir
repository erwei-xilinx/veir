// Layer 5: air.launch / air.segment / air.herd / air.rank (SEMANTICS.md D37-D44). Each op is a
// start event, its body once per instance, and an end event (its token) that waits for every
// event inside (D38).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer5_hierarchy.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer5_hierarchy.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP

// mlir-air's channel_drain_hierarchy.mlir after air-dependency deadlocks (AIR-012).
// RACES-LABEL: @drain_dep: 12 event(s)
// RACES-NEXT:  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: event 6 {{.*}}(air.channel.put), {{.*}}(end of a hierarchy op){{.*}}(air.channel.get)
// RACES-LABEL: @drain_fixed: 12 event(s), 3 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @herd_tiles: 18 event(s), 6 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock
// RACES-LABEL: @herd_shared_write: 6 event(s), 2 buffer(s), {{[1-9][0-9]*}} race(s)
// RACES:       race: WAW on %arg0 element 0 between the transfer of element 0 of event {{[1-4]}} (iteration {{.*}}) (air.dma_memcpy_nd) and the transfer of element 0 of event {{[1-4]}} (iteration {{.*}}) (air.dma_memcpy_nd)
// RACES-LABEL: @sync_herd: 4 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @async_herd_unordered: 4 event(s), 3 buffer(s), 1 race(s)
// RACES:       race: WAR on %arg0 element {{[0-9]+}} between the read of element {{[0-9]+}} of event 3 (air.dma_memcpy_nd) and the transfer of element {{[0-9]+}} of event 1 (iteration [0, 0]) (air.dma_memcpy_nd)
// RACES-LABEL: @token_arg: 4 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @launch_talk:
// RACES-NEXT:  error: @L[1]: event 1's put feeds event 4's get across two instances of one air.launch ([0] and [1]), which may run one after another (D37)
// RACES-NEXT:  error: @L[0]: event 3's put feeds event 2's get across two instances of one air.launch ([1] and [0]), which may run one after another (D37)
// RACES-LABEL: @nested_segment: 6 event(s), 3 buffer(s), 0 race(s)
// RACES-LABEL: @rank_talk: 6 event(s), 2 buffer(s), 0 race(s)
// RACES-NEXT:  no deadlock

// INTERP-LABEL: @drain_dep: deadlocks
// INTERP-LABEL: @drain_fixed: {{.*}}%arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32], %arg1 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @herd_tiles: {{.*}}%arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @sync_herd: {{.*}}%arg2 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @async_herd_unordered:
// INTERP-NEXT:  races (see `races`); an execution with {{.*}} ends differently
// INTERP-LABEL: @token_arg:
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @rank_talk: %arg0 = [1001 : i32, 1000 : i32, 2 : i32, 3 : i32]

// Decision D47 -- an L1 buffer outside the herd, used whole by every tile, is one buffer (D46 = A):
// the tiles race. AIR privatises it per core (AIR-023), a hack.
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d47_herd_scratch.mlir 2>/dev/null | filecheck %s --check-prefix=SCRATCH
// SCRATCH: @herd_scratch: 4 event(s), 2 buffer(s), 1 race(s)
// SCRATCH:      race: {{.*}} between finish of event 1 (iteration [0, 0]) (a synchronous op) and finish of event 2 (iteration [1, 0]) (a synchronous op)
