// Refused by layer 2; see Test/Air/diagnostics.mlir.
"builtin.module"() ({
  "func.func"() <{function_type = (memref<8xi32>, memref<4xi32>) -> (), sym_name = "dma_on_view"}> ({
  ^bb0(%arg0: memref<8xi32>, %arg1: memref<4xi32>):
    %0:2 = "air.execute"() ({
      %2 = "memref.subview"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 4>, static_sizes = array<i64: 4>, static_strides = array<i64: 1>}> : (memref<8xi32>) -> memref<4xi32, strided<[1], offset: 4>>
      "air.execute_terminator"(%2) : (memref<4xi32, strided<[1], offset: 4>>) -> ()
    }) : () -> (!air.async.token, memref<4xi32, strided<[1], offset: 4>>)
    %1 = "air.dma_memcpy_nd"(%0#0, %arg1, %0#1) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32, strided<[1], offset: 4>>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
