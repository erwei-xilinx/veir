"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "In"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "Out"}> : () -> ()
  "func.func"() <{function_type = (memref<32xi32>, memref<32xi32>) -> (), sym_name = "f"}> ({
  ^bb0(%arg0: memref<32xi32>, %arg1: memref<32xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<32xi32>, %arg5: memref<32xi32>):
      %1 = "arith.constant"() <{value = 0 : index}> : () -> index
      %2 = "arith.constant"() <{value = 4 : index}> : () -> index
      %3 = "arith.constant"() <{value = 8 : index}> : () -> index
      %4 = "arith.constant"() <{value = 1 : index}> : () -> index
      "scf.for"(%1, %2, %4) ({
      ^bb0(%arg12: index):
        %12 = "arith.muli"(%arg12, %3) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
        "air.channel.put"(%1, %1, %arg4, %12, %3, %4) <{chan_name = @In, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<32xi32>, index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) : (index, index, index) -> ()
      "air.segment"() <{operandSegmentSizes = array<i32: 0, 0, 0>, sym_name = "seg"}> ({
        %6 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%6, %6) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg7: index, %arg8: index, %arg9: index, %arg10: index):
          %7 = "arith.constant"() <{value = 0 : index}> : () -> index
          %8 = "arith.constant"() <{value = 1 : index}> : () -> index
          %9 = "arith.constant"() <{value = 4 : index}> : () -> index
          "scf.for"(%7, %9, %8) ({
          ^bb0(%arg11: index):
            %10 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
            %11 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
            "air.channel.get"(%arg7, %arg8, %10) <{chan_name = @In, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (index, index, memref<8xi32, 2>) -> ()
            "memref.copy"(%10, %11) : (memref<8xi32, 2>, memref<8xi32, 2>) -> ()
            "air.channel.put"(%arg7, %arg8, %11) <{chan_name = @Out, operandSegmentSizes = array<i32: 0, 2, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (index, index, memref<8xi32, 2>) -> ()
            "memref.dealloc"(%10) : (memref<8xi32, 2>) -> ()
            "memref.dealloc"(%11) : (memref<8xi32, 2>) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> ()
        "air.segment_terminator"() : () -> ()
      }) : () -> ()
      "scf.for"(%1, %2, %4) ({
      ^bb0(%arg6: index):
        %5 = "arith.muli"(%arg6, %3) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
        "air.channel.get"(%1, %1, %arg5, %5, %3, %4) <{chan_name = @Out, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (index, index, memref<32xi32>, index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) : (index, index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<32xi32>, memref<32xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
