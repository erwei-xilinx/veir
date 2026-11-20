"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "short_offsets"}> ({
    %20 = "arith.constant"() <{value = 1 : index}> : () -> index
    %21 = "arith.constant"() <{value = 2 : index}> : () -> index
    %22 = "arith.constant"() <{value = 6 : index}> : () -> index
    %23 = "arith.constant"() <{value = 8 : index}> : () -> index
    %24 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<2x8xi32>
    %25 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %26 = "air.wait_all"() : () -> !air.async.token
    %27 = "air.channel.put"(%26, %24, %22, %21, %21, %23, %20) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 2, 2, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<2x8xi32>, index, index, index, index, index) -> !air.async.token
    %28 = "air.channel.get"(%26, %25) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "air.wait_all"(%27, %28) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "wait_in_execute"}> ({
    %12 = "arith.constant"() <{value = 0 : index}> : () -> index
    %13 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %14 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %15 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %16 = "air.wait_all"() : () -> !air.async.token
    %17 = "air.channel.put"(%16, %14) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    %18 = "air.channel.get"(%16, %15) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    %19 = "air.execute"() ({
      "air.wait_all"(%18) : (!air.async.token) -> ()
      "memref.store"(%13, %15, %12) : (i32, memref<4xi32>, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%17, %19) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "dest_zero"}> ({
    %6 = "arith.constant"() <{value = 0 : index}> : () -> index
    %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %8 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %9 = "air.wait_all"() : () -> !air.async.token
    %10 = "air.channel.put"(%9, %7, %6) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 1>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, index) -> !air.async.token
    %11 = "air.channel.get"(%9, %8) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "air.wait_all"(%10, %11) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "dest_one"}> ({
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %2 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %3 = "air.wait_all"() : () -> !air.async.token
    %4 = "air.channel.put"(%3, %1, %0) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 1>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, index) -> !air.async.token
    %5 = "air.channel.get"(%3, %2) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "air.wait_all"(%4, %5) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
