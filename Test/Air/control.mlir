// scf.if, affine.if, scf.index_switch and affine.apply, decided by values known before running
// (tile ids, constants, loop induction variables), as upstream MLIR defines them. Non-integer
// constants are opaque values (VEIR-004, D22).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/control.mlir 2>/dev/null | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/control.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/refuse_runtime_branch.mlir 2>&1 | filecheck %s --check-prefix=RUNTIME

// RACES-LABEL: @if_on_tile: 4 event(s), 2 buffer(s), 0 race(s)
// RACES-LABEL: @apply_offset: 4 event(s), 2 buffer(s), 0 race(s)
// RACES-LABEL: @affine_if: 3 event(s), 2 buffer(s), 0 race(s)
// RACES-LABEL: @index_switch: 4 event(s), 2 buffer(s), 0 race(s)
// RACES-LABEL: @if_same_branch: 4 event(s), 2 buffer(s), 1 race(s)
// RACES-NEXT:  no deadlock
// RACES-NEXT:  race: WAW on %arg0 element {{[0-9]+}} between the transfer of element {{[0-9]+}} of event 1 (iteration [0, 0]) (air.dma_memcpy_nd) and the transfer of element {{[0-9]+}} of event 2 (iteration [1, 0]) (air.dma_memcpy_nd)
// RACES-LABEL: @float_fill: 1 event(s), 1 buffer(s), 0 race(s)

// INTERP-LABEL: @if_on_tile: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @apply_offset: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @affine_if: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-NEXT:  race-free: every execution ends with this memory
// INTERP-LABEL: @index_switch: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @if_same_branch: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32]
// The two tiles write the same values, so the race does not change the outcome.
// INTERP-NEXT:  races (see `races`); an execution with {{.*}} ends the same
// INTERP-LABEL: @float_fill: %arg0 = [opaque<{{.*}}>, opaque<{{.*}}>, opaque<{{.*}}>, opaque<{{.*}}>]

// RUNTIME: 'scf.if': the branch condition is not known before running (a branch on a runtime value is not supported)
