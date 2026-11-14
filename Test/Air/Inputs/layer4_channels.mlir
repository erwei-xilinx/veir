// Generated from layer4_channels.air.mlir.src with air-opt (mlir-air 9b81b5de0) --mlir-print-op-generic --mlir-print-local-scope
"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [], sym_name = "C"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "B"}> {broadcast_shape = [1, 2]} : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "rendezvous"}> ({
  ^bb0(%arg22: memref<4xi32>, %arg23: memref<4xi32>):
    %25 = "air.channel.put"(%arg22) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %26 = "air.channel.get"(%arg23) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "rendezvous_deadlock"}> ({
  ^bb0(%arg20: memref<4xi32>, %arg21: memref<4xi32>):
    %23 = "air.channel.put"(%arg20) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %24 = "air.channel.get"(%23, %arg21) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "sync_put_then_get"}> ({
  ^bb0(%arg18: memref<4xi32>, %arg19: memref<4xi32>):
    "air.channel.put"(%arg18) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> ()
    "air.channel.get"(%arg19) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "sync_get_then_put"}> ({
  ^bb0(%arg16: memref<4xi32>, %arg17: memref<4xi32>):
    "air.channel.get"(%arg17) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> ()
    "air.channel.put"(%arg16) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "stream_split"}> ({
  ^bb0(%arg13: memref<8xi32>, %arg14: memref<4xi32>, %arg15: memref<4xi32>):
    %20 = "air.channel.put"(%arg13) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>) -> !air.async.token
    %21 = "air.channel.get"(%arg14) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %22 = "air.channel.get"(%21, %arg15) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "order_race"}> ({
  ^bb0(%arg9: memref<4xi32>, %arg10: memref<4xi32>, %arg11: memref<4xi32>, %arg12: memref<4xi32>):
    %16 = "air.channel.put"(%arg9) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %17 = "air.channel.put"(%arg10) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %18 = "air.channel.get"(%arg11) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %19 = "air.channel.get"(%18, %arg12) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "broadcast"}> ({
  ^bb0(%arg6: memref<4xi32>, %arg7: memref<4xi32>, %arg8: memref<4xi32>):
    %11 = "arith.constant"() <{value = 0 : index}> : () -> index
    %12 = "arith.constant"() <{value = 1 : index}> : () -> index
    %13 = "air.channel.put"(%11, %11, %arg6) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    %14 = "air.channel.get"(%11, %11, %arg7) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    %15 = "air.channel.get"(%11, %12, %arg8) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "broadcast_missing"}> ({
  ^bb0(%arg4: memref<4xi32>, %arg5: memref<4xi32>):
    %8 = "arith.constant"() <{value = 0 : index}> : () -> index
    %9 = "air.channel.put"(%8, %8, %arg4) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    %10 = "air.channel.get"(%8, %8, %arg5) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "starved_get"}> ({
  ^bb0(%arg2: memref<4xi32>, %arg3: memref<8xi32>):
    %6 = "air.channel.put"(%arg2) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %7 = "air.channel.get"(%arg3) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<2xi32>, memref<5xi32>) -> (), sym_name = "padding"}> ({
  ^bb0(%arg0: memref<2xi32>, %arg1: memref<5xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 2 : index}> : () -> index
    %3 = "arith.constant"() <{value = 3 : index}> : () -> index
    %4 = "air.channel.put"(%arg0, %0, %2, %1) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1, 0>, pad_after = array<i32: 0>, pad_before = array<i32: 1>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<2xi32>, index, index, index) -> !air.async.token
    %5 = "air.channel.get"(%arg1, %0, %3, %1) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1>, pad_after = array<i32: 1>, pad_before = array<i32: 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (memref<5xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
