"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (memref<?x8xi32>) -> (), sym_name = "cast_too_small"}> ({
  ^bb0(%arg0: memref<?x8xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 2 : index}> : () -> index
    %3 = "arith.constant"() <{value = 8 : index}> : () -> index
    %4 = "memref.cast"(%arg0) : (memref<?x8xi32>) -> memref<2x8xi32>
    %5 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %6 = "air.wait_all"() : () -> !air.async.token
    %7 = "air.channel.put"(%6, %arg0, %2, %0, %2, %3, %3, %1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 2, 2, 2, 0>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<?x8xi32>, index, index, index, index, index, index) -> !air.async.token
    %8 = "air.channel.get"(%6, %5) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<16xi32>) -> !air.async.token
    "air.wait_all"(%7, %8) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
