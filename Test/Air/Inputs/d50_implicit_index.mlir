"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "implicit_index"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "air.channel.put"(%arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
    %2 = "air.channel.get"(%0, %0, %arg1) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
