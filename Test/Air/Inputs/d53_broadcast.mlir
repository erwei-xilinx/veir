"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "B"}> {broadcast_shape = [2 : index, 1 : index]} : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "Sig"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "mixed_signalled"}> ({
  ^bb0(%arg18: memref<4xi32>):
    %18 = "arith.constant"() <{value = 1 : index}> : () -> index
    %19 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.launch"(%18, %arg18) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg19: index, %arg20: index, %arg21: memref<4xi32>):
      "air.segment"(%arg21) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg22: memref<4xi32>):
        %20 = "arith.constant"() <{value = 1 : index}> : () -> index
        %21 = "arith.constant"() <{value = 2 : index}> : () -> index
        %22 = "arith.constant"() <{value = 0 : index}> : () -> index
        %23 = "air.channel.put"(%22, %22, %arg22) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
        "air.herd"(%21, %20) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg23: index, %arg24: index, %arg25: index, %arg26: index):
          %24 = "arith.constant"() <{value = 0 : index}> : () -> index
          %25 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
          %26 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32, 2>
          %27 = "arith.cmpi"(%arg23, %24) <{predicate = 0 : i64}> : (index, index) -> i1
          "scf.if"(%27) ({
            "air.channel.get"(%arg23, %arg24, %25) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> ()
            "air.channel.put"(%26) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }, {
            "air.channel.get"(%26) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1xi32, 2>) -> ()
            %28 = "air.channel.get"(%arg23, %arg24, %25) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> !air.async.token
            "air.wait_all"(%28) : (!air.async.token) -> ()
            "scf.yield"() : () -> ()
          }) : (i1) -> ()
          "memref.dealloc"(%25) : (memref<4xi32, 2>) -> ()
          "memref.dealloc"(%26) : (memref<1xi32, 2>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "mixed_free"}> ({
  ^bb0(%arg9: memref<4xi32>):
    %9 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%9, %arg9) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg10: index, %arg11: index, %arg12: memref<4xi32>):
      "air.segment"(%arg12) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg13: memref<4xi32>):
        %10 = "arith.constant"() <{value = 1 : index}> : () -> index
        %11 = "arith.constant"() <{value = 2 : index}> : () -> index
        %12 = "arith.constant"() <{value = 0 : index}> : () -> index
        %13 = "air.channel.put"(%12, %12, %arg13) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> !air.async.token
        "air.herd"(%11, %10) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg14: index, %arg15: index, %arg16: index, %arg17: index):
          %14 = "arith.constant"() <{value = 0 : index}> : () -> index
          %15 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
          %16 = "arith.cmpi"(%arg14, %14) <{predicate = 0 : i64}> : (index, index) -> i1
          "scf.if"(%16) ({
            "air.channel.get"(%arg14, %arg15, %15) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }, {
            %17 = "air.channel.get"(%arg14, %arg15, %15) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> !air.async.token
            "air.wait_all"(%17) : (!air.async.token) -> ()
            "scf.yield"() : () -> ()
          }) : (i1) -> ()
          "memref.dealloc"(%15) : (memref<4xi32, 2>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "sync_put_signalled"}> ({
  ^bb0(%arg0: memref<4xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: memref<4xi32>):
      "air.segment"(%arg3) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg4: memref<4xi32>):
        %1 = "arith.constant"() <{value = 1 : index}> : () -> index
        %2 = "arith.constant"() <{value = 2 : index}> : () -> index
        %3 = "arith.constant"() <{value = 0 : index}> : () -> index
        "air.channel.put"(%3, %3, %arg4) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<4xi32>) -> ()
        "air.herd"(%2, %1) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg5: index, %arg6: index, %arg7: index, %arg8: index):
          %4 = "arith.constant"() <{value = 0 : index}> : () -> index
          %5 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
          %6 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32, 2>
          %7 = "arith.cmpi"(%arg5, %4) <{predicate = 0 : i64}> : (index, index) -> i1
          "scf.if"(%7) ({
            "air.channel.get"(%arg5, %arg6, %5) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> ()
            "air.channel.put"(%6) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }, {
            "air.channel.get"(%6) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1xi32, 2>) -> ()
            %8 = "air.channel.get"(%arg5, %arg6, %5) <{chan_name = @B, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<4xi32, 2>) -> !air.async.token
            "air.wait_all"(%8) : (!air.async.token) -> ()
            "scf.yield"() : () -> ()
          }) : (i1) -> ()
          "memref.dealloc"(%5) : (memref<4xi32, 2>) -> ()
          "memref.dealloc"(%6) : (memref<1xi32, 2>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
