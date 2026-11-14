"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "src_rank_out_of_range"}> ({
  ^bb0(%arg0: memref<4xi32>):
    %0 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.rank"(%0, %arg0) <{operandSegmentSizes = array<i32: 0, 0, 1, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: memref<4xi32>):
      %1 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
      "air.dma_memcpy_nd"(%arg3, %1) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, src_rank = 5 : i64, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
      "air.rank_terminator"() : () -> ()
    }) : (index, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
