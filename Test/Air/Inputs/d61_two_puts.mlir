"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "in"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 2], sym_name = "mid"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "two_puts"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<4xi32>, %arg5: memref<8xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      "air.channel.put"(%1, %1, %arg4) <{chan_name = @in, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.segment"(%arg5) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg6: memref<8xi32>):
        %2 = "arith.constant"() <{value = 0 : index}> : () -> index
        %3 = "arith.constant"() <{value = 1 : index}> : () -> index
        %4 = "arith.constant"() <{value = 2 : index}> : () -> index
        %5 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.refeed_count = 2 : i32} : () -> memref<4xi32, 1 : i32>
        "air.channel.get"(%2, %2, %5) <{chan_name = @in, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 1 : i32>) -> ()
        "air.channel.put"(%2, %2, %5) <{chan_name = @mid, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32, 1 : i32>) -> ()
        "air.channel.put"(%2, %3, %5) <{chan_name = @mid, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32, 1 : i32>) -> ()
        "air.herd"(%3, %4, %arg6) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg7: index, %arg8: index, %arg9: index, %arg10: index, %arg11: memref<8xi32>):
          %6 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2 : i32>
          "air.channel.get"(%arg7, %arg8, %6) <{chan_name = @mid, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2 : i32>) -> ()
          "memref.dealloc"(%6) : (memref<4xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>) -> ()
        "memref.dealloc"(%5) : (memref<4xi32, 1 : i32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
