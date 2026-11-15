// memref.global (upstream MLIR): one buffer per global, holding its initial value. Empty offsets
// with sizes and strides mean offset 0 (D14a, as AIR's get1DOffset reads them).

// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/global_table.mlir 2>/dev/null | filecheck %s
// CHECK: @global_table: %arg0 = [1..4]
