"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>, memref<2xi32>) -> (), sym_name = "offset_view"}> ({
  ^bb0(%arg0: memref<16xi32>, %arg1: memref<2xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<16xi32>, %arg5: memref<2xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 2 : index}> : () -> index
      %3 = "arith.constant"() <{value = 1 : index}> : () -> index
      %4 = "memref.subview"(%arg4) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 4>, static_sizes = array<i64: 8>, static_strides = array<i64: 1>}> : (memref<16xi32>) -> memref<8xi32, strided<[1], offset: 4>>
      "air.dma_memcpy_nd"(%arg5, %4, %1, %2, %2) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<2xi32>, memref<8xi32, strided<[1], offset: 4>>, index, index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<16xi32>, memref<2xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
