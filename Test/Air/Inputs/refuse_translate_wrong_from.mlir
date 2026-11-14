"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>, memref<2xindex>) -> (), sym_name = "translate_wrong_from"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<2xindex>):
    %0 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.rank"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<4xi32>, %arg5: memref<2xindex>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 1 : index}> : () -> index
      %3 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
      %4 = "air.translate"(%3, %2, %1, %arg5) : (memref<4xi32>, index, index, memref<2xindex>) -> memref<4xi32>
      "air.dma_memcpy_nd"(%arg4, %4) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
      "air.rank_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<2xindex>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
