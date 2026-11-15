"builtin.module"() ({
  "memref.global"() <{constant, initial_value = dense<[1, 2, 3, 4]> : tensor<4xi32>, sym_name = "table", sym_visibility = "private", type = memref<4xi32>}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "global_table"}> ({
  ^bb0(%arg0: memref<4xi32>):
    %0 = "memref.get_global"() <{name = @table}> : () -> memref<4xi32>
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%1, %0, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: memref<4xi32>, %arg4: memref<4xi32>):
      %2 = "arith.constant"() <{value = 0 : index}> : () -> index
      %3 = "arith.constant"() <{value = 1 : index}> : () -> index
      %4 = "arith.constant"() <{value = 4 : index}> : () -> index
      %5 = "air.channel.put"(%2, %2, %arg3, %4, %3) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 2, 1, 0, 1, 1, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<4xi32>, index, index) -> !air.async.token
      "air.channel.get"(%2, %2, %arg4) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
