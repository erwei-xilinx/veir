"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "sym_outside_rank"}> ({
  ^bb0(%arg0: memref<4xi32>):
    %0 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
    "air.dma_memcpy_nd"(%0, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
