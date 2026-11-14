"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "kernel", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "use_after_dealloc"}> ({
  ^bb0(%arg17: memref<4xi32>):
    %11 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    "memref.dealloc"(%11) : (memref<4xi32>) -> ()
    %12 = "air.dma_memcpy_nd"(%11, %arg17) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "call_then_dma"}> ({
  ^bb0(%arg15: memref<4xi32>, %arg16: memref<4xi32>):
    "func.call"(%arg15) <{callee = @kernel}> : (memref<4xi32>) -> ()
    %10 = "air.dma_memcpy_nd"(%arg16, %arg15) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "dma_then_call"}> ({
  ^bb0(%arg13: memref<4xi32>, %arg14: memref<4xi32>):
    %9 = "air.dma_memcpy_nd"(%arg14, %arg13) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.call"(%arg13) <{callee = @kernel}> : (memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "sync_herd_body"}> ({
  ^bb0(%arg8: memref<4xi32>):
    %7 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.channel.put"(%arg8) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> ()
    "air.herd"(%7, %7) <{operandSegmentSizes = array<i32: 0, 2, 0>}> ({
    ^bb0(%arg9: index, %arg10: index, %arg11: index, %arg12: index):
      %8 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
      "air.channel.get"(%8) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32, 2>) -> ()
      "memref.dealloc"(%8) : (memref<4xi32, 2>) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<1024xi32>) -> (), sym_name = "fifo_before_loop"}> ({
  ^bb0(%arg0: memref<1024xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 8 : index}> : () -> index
    "air.channel.put"(%arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1024xi32>) -> ()
    "scf.for"(%0, %2, %1) ({
    ^bb0(%arg7: index):
      "air.channel.put"(%arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1024xi32>) -> ()
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    %3 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1024xi32, 2>
    "air.herd"(%1, %1, %3) <{operandSegmentSizes = array<i32: 0, 2, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: index, %arg4: index, %arg5: memref<1024xi32, 2>):
      %4 = "arith.constant"() <{value = 0 : index}> : () -> index
      %5 = "arith.constant"() <{value = 1 : index}> : () -> index
      %6 = "arith.constant"() <{value = 8 : index}> : () -> index
      "air.channel.get"(%arg5) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1024xi32, 2>) -> ()
      "scf.for"(%4, %6, %5) ({
      ^bb0(%arg6: index):
        "air.channel.get"(%arg5) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1024xi32, 2>) -> ()
        "scf.yield"() : () -> ()
      }) : (index, index, index) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<1024xi32, 2>) -> ()
    "memref.dealloc"(%3) : (memref<1024xi32, 2>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
