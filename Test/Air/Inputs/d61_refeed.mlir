"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c3"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c2"}> {air.refeed_count = 2 : i32} : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "in"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "mid"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "g"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<12xi32>) -> (), sym_name = "op_count"}> ({
  ^bb0(%arg36: memref<4xi32>, %arg37: memref<12xi32>):
    %14 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%14, %arg36, %arg37) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg38: index, %arg39: index, %arg40: memref<4xi32>, %arg41: memref<12xi32>):
      %15 = "arith.constant"() <{value = 0 : index}> : () -> index
      %16 = "air.channel.put"(%15, %15, %arg40) <{chan_name = @c3, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {air.refeed_count = 3 : i32} : (index, index, memref<4xi32>) -> !air.async.token
      "air.segment"(%arg41) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg42: memref<12xi32>):
        %18 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%18, %18, %arg42) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg43: index, %arg44: index, %arg45: index, %arg46: index, %arg47: memref<12xi32>):
          %19 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<12xi32, 2 : i32>
          "air.channel.get"(%arg43, %arg44, %19) <{chan_name = @c3, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<12xi32, 2 : i32>) -> ()
          "air.dma_memcpy_nd"(%arg47, %19) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<12xi32>, memref<12xi32, 2 : i32>) -> ()
          "memref.dealloc"(%19) : (memref<12xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<12xi32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<12xi32>) -> ()
      %17 = "air.wait_all"(%16) : (!air.async.token) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<12xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "decl_count"}> ({
  ^bb0(%arg24: memref<4xi32>, %arg25: memref<8xi32>):
    %10 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%10, %arg24, %arg25) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg26: index, %arg27: index, %arg28: memref<4xi32>, %arg29: memref<8xi32>):
      %11 = "arith.constant"() <{value = 0 : index}> : () -> index
      "air.channel.put"(%11, %11, %arg28) <{chan_name = @c2, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.segment"(%arg29) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg30: memref<8xi32>):
        %12 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%12, %12, %arg30) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg31: index, %arg32: index, %arg33: index, %arg34: index, %arg35: memref<8xi32>):
          %13 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2 : i32>
          "air.channel.get"(%arg31, %arg32, %13) <{chan_name = @c2, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<8xi32, 2 : i32>) -> ()
          "air.dma_memcpy_nd"(%arg35, %13) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>, memref<8xi32, 2 : i32>) -> ()
          "memref.dealloc"(%13) : (memref<8xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "alloc_count"}> ({
  ^bb0(%arg12: memref<4xi32>, %arg13: memref<8xi32>):
    %4 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%4, %arg12, %arg13) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg14: index, %arg15: index, %arg16: memref<4xi32>, %arg17: memref<8xi32>):
      %5 = "arith.constant"() <{value = 0 : index}> : () -> index
      "air.channel.put"(%5, %5, %arg16) <{chan_name = @in, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.segment"(%arg17) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg18: memref<8xi32>):
        %6 = "arith.constant"() <{value = 0 : index}> : () -> index
        %7 = "arith.constant"() <{value = 1 : index}> : () -> index
        %8 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.refeed_count = 2 : i32} : () -> memref<4xi32, 1 : i32>
        "air.channel.get"(%6, %6, %8) <{chan_name = @in, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 1 : i32>) -> ()
        "air.channel.put"(%6, %6, %8) <{chan_name = @mid, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32, 1 : i32>) -> ()
        "air.herd"(%7, %7, %arg18) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg19: index, %arg20: index, %arg21: index, %arg22: index, %arg23: memref<8xi32>):
          %9 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2 : i32>
          "air.channel.get"(%arg19, %arg20, %9) <{chan_name = @mid, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<8xi32, 2 : i32>) -> ()
          "air.dma_memcpy_nd"(%arg23, %9) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>, memref<8xi32, 2 : i32>) -> ()
          "memref.dealloc"(%9) : (memref<8xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>) -> ()
        "memref.dealloc"(%8) : (memref<4xi32, 1 : i32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "get_count"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<4xi32>, %arg5: memref<4xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      "air.channel.put"(%1, %1, %arg4) <{chan_name = @g, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
      "air.segment"(%arg5) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg6: memref<4xi32>):
        %2 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%2, %2, %arg6) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg7: index, %arg8: index, %arg9: index, %arg10: index, %arg11: memref<4xi32>):
          %3 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2 : i32>
          "air.channel.get"(%arg7, %arg8, %3) <{chan_name = @g, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {air.refeed_count = 5 : i32} : (index, index, memref<4xi32, 2 : i32>) -> ()
          "air.dma_memcpy_nd"(%arg11, %3) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32, 2 : i32>) -> ()
          "memref.dealloc"(%3) : (memref<4xi32, 2 : i32>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<4xi32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
