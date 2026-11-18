"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "lo"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "hi"}> : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<4xi32>) -> (), sym_name = "offset_from_execute"}> ({
  ^bb0(%arg6: memref<8xi32>, %arg7: memref<4xi32>):
    %12 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%12, %arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg8: index, %arg9: index, %arg10: memref<8xi32>, %arg11: memref<4xi32>):
      %13 = "arith.constant"() <{value = 0 : index}> : () -> index
      %14 = "arith.constant"() <{value = 4 : index}> : () -> index
      %15 = "arith.constant"() <{value = 1 : index}> : () -> index
      %16:2 = "air.execute"() ({
        %19 = "arith.constant"() <{value = 4 : index}> : () -> index
        "air.execute_terminator"(%19) : (index) -> ()
      }) : () -> (!air.async.token, index)
      %17 = "air.channel.put"(%16#0, %13, %13, %arg10, %16#1, %14, %15) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      %18 = "air.channel.get"(%13, %13, %arg11) <{chan_name = @c, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
      "air.wait_all"(%17, %18) : (!air.async.token, !air.async.token) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<8xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "two_halves"}> ({
  ^bb0(%arg0: memref<8xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<8xi32>, %arg5: memref<8xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 4 : index}> : () -> index
      %3 = "arith.constant"() <{value = 1 : index}> : () -> index
      %4:2 = "air.execute"() ({
        %11 = "arith.constant"() <{value = 0 : index}> : () -> index
        "air.execute_terminator"(%11) : (index) -> ()
      }) : () -> (!air.async.token, index)
      %5:2 = "air.execute"() ({
        %10 = "arith.constant"() <{value = 4 : index}> : () -> index
        "air.execute_terminator"(%10) : (index) -> ()
      }) : () -> (!air.async.token, index)
      %6 = "air.channel.put"(%1, %1, %arg4, %1, %2, %3) <{chan_name = @lo, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<8xi32>, index, index, index) -> !air.async.token
      %7 = "air.channel.put"(%1, %1, %arg4, %2, %2, %3) <{chan_name = @hi, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<8xi32>, index, index, index) -> !air.async.token
      %8 = "air.channel.get"(%4#0, %1, %1, %arg5, %4#1, %2, %3) <{chan_name = @lo, operandSegmentSizes = array<i32: 1, 2, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      %9 = "air.channel.get"(%5#0, %1, %1, %arg5, %5#1, %2, %3) <{chan_name = @hi, operandSegmentSizes = array<i32: 1, 2, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      "air.wait_all"(%6, %7, %8, %9) : (!air.async.token, !air.async.token, !air.async.token, !air.async.token) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<8xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
