"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (memref<4x2xi32>, memref<4xi32>) -> (), sym_name = "collapsed"}> ({
  ^bb0(%arg6: memref<4x2xi32>, %arg7: memref<4xi32>):
    %6 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%6, %arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg8: index, %arg9: index, %arg10: memref<4x2xi32>, %arg11: memref<4xi32>):
      %7 = "arith.constant"() <{value = 0 : index}> : () -> index
      %8 = "arith.constant"() <{value = 2 : index}> : () -> index
      %9 = "arith.constant"() <{value = 4 : index}> : () -> index
      %10 = "memref.collapse_shape"(%arg10) <{reassociation = [[0, 1]]}> : (memref<4x2xi32>) -> memref<8xi32>
      "air.channel.put"(%7, %7, %10, %7, %9, %8) <{chan_name = @c, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<8xi32>, index, index, index) -> ()
      "air.channel.get"(%7, %7, %arg11) <{chan_name = @c, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4x2xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<2x4x1xi32>, memref<4xi32>) -> (), sym_name = "rank_reduced"}> ({
  ^bb0(%arg0: memref<2x4x1xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<2x4x1xi32>, %arg5: memref<4xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 2 : index}> : () -> index
      %3 = "arith.constant"() <{value = 4 : index}> : () -> index
      %4 = "arith.constant"() <{value = 1 : index}> : () -> index
      %5 = "memref.subview"(%arg4) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 0, 0, 0>, static_sizes = array<i64: 2, 4, 1>, static_strides = array<i64: 1, 1, 1>}> : (memref<2x4x1xi32>) -> memref<2x4xi32, strided<[4, 1]>>
      "air.dma_memcpy_nd"(%arg5, %5, %1, %4, %2, %2, %3, %4) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 2, 2, 2>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (memref<4xi32>, memref<2x4xi32, strided<[4, 1]>>, index, index, index, index, index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<2x4x1xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
