// Refused by layer 2; see Test/Air/diagnostics.mlir.
"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "blocking_dma"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    "air.dma_memcpy_nd"(%arg1, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
