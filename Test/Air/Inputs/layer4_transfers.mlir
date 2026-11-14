"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "same_place"}> ({
  ^bb0(%arg8: memref<4xi32>):
    %16 = "arith.constant"() <{value = 0 : index}> : () -> index
    %17 = "arith.constant"() <{value = 1 : index}> : () -> index
    %18 = "arith.constant"() <{value = 2 : index}> : () -> index
    %19 = "air.channel.put"(%arg8, %16, %18, %17) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    %20 = "air.channel.get"(%arg8, %16, %18, %17) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "shift_down"}> ({
  ^bb0(%arg7: memref<4xi32>):
    %11 = "arith.constant"() <{value = 0 : index}> : () -> index
    %12 = "arith.constant"() <{value = 1 : index}> : () -> index
    %13 = "arith.constant"() <{value = 2 : index}> : () -> index
    %14 = "air.channel.put"(%arg7, %12, %13, %12) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    %15 = "air.channel.get"(%arg7, %11, %13, %12) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "shift_up"}> ({
  ^bb0(%arg6: memref<4xi32>):
    %6 = "arith.constant"() <{value = 0 : index}> : () -> index
    %7 = "arith.constant"() <{value = 1 : index}> : () -> index
    %8 = "arith.constant"() <{value = 2 : index}> : () -> index
    %9 = "air.channel.put"(%arg6, %6, %8, %7) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    %10 = "air.channel.get"(%arg6, %7, %8, %7) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "reuse_after_get"}> ({
  ^bb0(%arg3: memref<4xi32>, %arg4: memref<4xi32>, %arg5: memref<4xi32>):
    %3 = "air.channel.put"(%arg3) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %4 = "air.channel.get"(%arg4) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %5 = "air.dma_memcpy_nd"(%4, %arg3, %arg5) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "reuse_unordered"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>, %arg2: memref<4xi32>):
    %0 = "air.channel.put"(%arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %1 = "air.channel.get"(%arg1) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %2 = "air.dma_memcpy_nd"(%arg0, %arg2) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
