"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "cin"}> : () -> ()
  "func.func"() <{function_type = (memref<16xi32>, memref<8xi32>) -> (), sym_name = "counted"}> ({
  ^bb0(%arg0: memref<16xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<16xi32>, %arg5: memref<8xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 4 : index}> : () -> index
      %3 = "arith.constant"() <{value = 1 : index}> : () -> index
      %4 = "air.channel.put"(%1, %1, %arg4, %1, %2, %3) <{chan_name = @cin, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> {air.device_issue = 0 : i64, air.device_issue_count = 2 : i64} : (index, index, memref<16xi32>, index, index, index) -> !air.async.token
      "air.segment"(%arg5) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg6: memref<8xi32>):
        %6 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%6, %6) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "router"}> ({
        ^bb0(%arg12: index, %arg13: index, %arg14: index, %arg15: index):
          %8 = "arith.constant"() <{value = 0 : i64}> : () -> i64
          %9 = "arith.constant"() <{value = 8 : i64}> : () -> i64
          "air.channel.issue"(%arg12, %arg13, %8) <{chan_name = @cin, issue_id = 0 : i64, operandSegmentSizes = array<i32: 0, 2, 1, 0>}> : (index, index, i64) -> ()
          "air.channel.issue"(%arg12, %arg13, %9) <{chan_name = @cin, issue_id = 0 : i64, operandSegmentSizes = array<i32: 0, 2, 1, 0>}> : (index, index, i64) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> ()
        "air.herd"(%6, %6, %arg6) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "mvm"}> ({
        ^bb0(%arg7: index, %arg8: index, %arg9: index, %arg10: index, %arg11: memref<8xi32>):
          %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2 : i32>
          "air.channel.get"(%arg7, %arg8, %7) <{chan_name = @cin, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<8xi32, 2 : i32>) -> ()
          "air.dma_memcpy_nd"(%arg11, %7) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>, memref<8xi32, 2 : i32>) -> ()
          "memref.dealloc"(%7) : (memref<8xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>) -> ()
      %5 = "air.wait_all"(%4) : (!air.async.token) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<16xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
