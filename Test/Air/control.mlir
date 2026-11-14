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
// RACES-NEXT:  race: WAW on %arg0 element 0 between event 1 (iteration [0, 0]) (air.dma_memcpy_nd) and event 2 (iteration [1, 0]) (air.dma_memcpy_nd)
// RACES-LABEL: @float_fill: 1 event(s), 1 buffer(s), 0 race(s)

// INTERP-LABEL: @if_on_tile: program order: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @apply_offset: program order: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @affine_if: program order: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-NEXT:  1 finishing order(s) allowed
// INTERP-LABEL: @index_switch: program order: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 1004 : i32, 1005 : i32, 1006 : i32, 1007 : i32]
// INTERP-LABEL: @if_same_branch: program order: %arg0 = [1000 : i32, 1001 : i32, 1002 : i32, 1003 : i32, 4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-LABEL: @float_fill: program order: %arg0 = [opaque<{{.*}}>, opaque<{{.*}}>, opaque<{{.*}}>, opaque<{{.*}}>]

// RUNTIME: 'scf.if': the branch condition is not known before running (a branch on a runtime value is not supported)
