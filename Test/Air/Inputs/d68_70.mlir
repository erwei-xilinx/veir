"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (memref<?x8xi32>) -> (), sym_name = "cast_shape"}> ({
  ^bb0(%arg4: memref<?x8xi32>):
    %28 = "arith.constant"() <{value = 0 : index}> : () -> index
    %29 = "arith.constant"() <{value = 1 : index}> : () -> index
    %30 = "arith.constant"() <{value = 2 : index}> : () -> index
    %31 = "arith.constant"() <{value = 8 : index}> : () -> index
    %32 = "memref.cast"(%arg4) : (memref<?x8xi32>) -> memref<4x8xi32>
    %33 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %34 = "air.wait_all"() : () -> !air.async.token
    %35 = "air.channel.put"(%34, %arg4, %30, %28, %30, %31, %31, %29) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 2, 2, 2, 0>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<?x8xi32>, index, index, index, index, index, index) -> !air.async.token
    %36 = "air.channel.get"(%34, %33) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<16xi32>) -> !air.async.token
    "air.wait_all"(%35, %36) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<?xi32>) -> (), sym_name = "copy_shape"}> ({
  ^bb0(%arg3: memref<?xi32>):
    %23 = "arith.constant"() <{value = 12 : index}> : () -> index
    %24 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %25 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %26 = "air.execute"() ({
      "memref.copy"(%arg3, %25) : (memref<?xi32>, memref<16xi32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %27 = "air.execute"(%26) ({
      "memref.store"(%24, %arg3, %23) : (i32, memref<?xi32>, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : (!air.async.token) -> !air.async.token
    "air.wait_all"(%27) : (!air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<?x8xi32>) -> (), sym_name = "leading_dyn"}> ({
  ^bb0(%arg2: memref<?x8xi32>):
    %15 = "arith.constant"() <{value = 0 : index}> : () -> index
    %16 = "arith.constant"() <{value = 1 : index}> : () -> index
    %17 = "arith.constant"() <{value = 4 : index}> : () -> index
    %18 = "arith.constant"() <{value = 8 : index}> : () -> index
    %19 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %20 = "air.wait_all"() : () -> !air.async.token
    %21 = "air.channel.put"(%20, %arg2, %17, %15, %16, %18, %18, %16) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 2, 2, 2, 0>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<?x8xi32>, index, index, index, index, index, index) -> !air.async.token
    %22 = "air.channel.get"(%20, %19, %15, %18, %16) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<16xi32>, index, index, index) -> !air.async.token
    "air.wait_all"(%21, %22) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "alloc_known"}> ({
    %9 = "arith.constant"() <{value = 4 : index}> : () -> index
    %10 = "memref.alloc"(%9) <{operandSegmentSizes = array<i32: 1, 0>}> : (index) -> memref<?xi32>
    %11 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %12 = "air.wait_all"() : () -> !air.async.token
    %13 = "air.channel.put"(%12, %10) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<?xi32>) -> !air.async.token
    %14 = "air.channel.get"(%12, %11) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "air.wait_all"(%13, %14) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "alloc_arg"}> ({
  ^bb0(%arg1: index):
    %4 = "memref.alloc"(%arg1) <{operandSegmentSizes = array<i32: 1, 0>}> : (index) -> memref<?xi32>
    %5 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %6 = "air.wait_all"() : () -> !air.async.token
    %7 = "air.channel.put"(%6, %4) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<?xi32>) -> !air.async.token
    %8 = "air.channel.get"(%6, %5) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
    "air.wait_all"(%7, %8) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<?x8xi32>) -> (), sym_name = "whole_leading_dyn"}> ({
  ^bb0(%arg0: memref<?x8xi32>):
    %0 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    %1 = "air.wait_all"() : () -> !air.async.token
    %2 = "air.channel.put"(%1, %arg0) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<?x8xi32>) -> !air.async.token
    %3 = "air.channel.get"(%1, %0) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<8xi32>) -> !air.async.token
    "air.wait_all"(%2, %3) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
