"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "per_instance"}> ({
  ^bb0(%arg0: memref<8xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<8xi32>, %arg5: memref<8xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 1 : index}> : () -> index
      %3 = "arith.constant"() <{value = 4 : index}> : () -> index
      %4 = "arith.muli"(%arg2, %3) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %5 = "air.channel.put"(%1, %1, %arg4, %4, %3, %2) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<8xi32>, index, index, index) -> !air.async.token
      "air.segment"(%arg5, %4) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg6: memref<8xi32>, %arg7: index):
        %6 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%6, %6, %arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 2, 2>, sym_name = "h"}> ({
        ^bb0(%arg8: index, %arg9: index, %arg10: index, %arg11: index, %arg12: memref<8xi32>, %arg13: index):
          %7 = "arith.constant"() <{value = 0 : index}> : () -> index
          %8 = "arith.constant"() <{value = 1 : index}> : () -> index
          %9 = "arith.constant"() <{value = 4 : index}> : () -> index
          %10 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
          "air.channel.get"(%7, %7, %10) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> ()
          "air.dma_memcpy_nd"(%arg12, %arg13, %9, %8, %10) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>, index, index, index, memref<4xi32, 2>) -> ()
          "memref.dealloc"(%10) : (memref<4xi32, 2>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<8xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
