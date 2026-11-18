"builtin.module"() ({
  "func.func"() <{function_type = (memref<*xi32>, memref<4xi32>) -> (), sym_name = "offset_past_one"}> ({
  ^bb0(%arg12: memref<*xi32>, %arg13: memref<4xi32>):
    %3 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%3, %arg12, %arg13) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg14: index, %arg15: index, %arg16: memref<*xi32>, %arg17: memref<4xi32>):
      %4 = "arith.constant"() <{value = 0 : index}> : () -> index
      %5 = "arith.constant"() <{value = 4 : index}> : () -> index
      %6 = "arith.constant"() <{value = 100 : index}> : () -> index
      %7 = "arith.constant"() <{value = 1 : index}> : () -> index
      "air.dma_memcpy_nd"(%arg17, %arg16, %6, %5, %7) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, memref<*xi32>, index, index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<*xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<*xi32>, memref<4xi32>) -> (), sym_name = "cast_to_shape"}> ({
  ^bb0(%arg6: memref<*xi32>, %arg7: memref<4xi32>):
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%1, %arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg8: index, %arg9: index, %arg10: memref<*xi32>, %arg11: memref<4xi32>):
      %2 = "memref.cast"(%arg10) : (memref<*xi32>) -> memref<4xi32>
      "air.dma_memcpy_nd"(%arg11, %2) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<*xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<*xi32>, memref<4xi32>) -> (), sym_name = "whole_pointer"}> ({
  ^bb0(%arg0: memref<*xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<*xi32>, %arg5: memref<4xi32>):
      "air.dma_memcpy_nd"(%arg5, %arg4) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<*xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<*xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
