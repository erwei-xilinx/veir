"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "C"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "kernel", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "use_after_dealloc"}> ({
  ^bb0(%arg19: memref<4xi32>):
    %31:2 = "air.execute"() ({
      %34 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
      "air.execute_terminator"(%34) : (memref<4xi32>) -> ()
    }) {id = 1 : i32} : () -> (!air.async.token, memref<4xi32>)
    %32 = "air.execute"(%31#0) ({
      "memref.dealloc"(%31#1) : (memref<4xi32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) {id = 2 : i32} : (!air.async.token) -> !air.async.token
    %33 = "air.dma_memcpy_nd"(%32, %31#1, %arg19) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 1 : i32} : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "call_then_dma"}> ({
  ^bb0(%arg17: memref<4xi32>, %arg18: memref<4xi32>):
    %29 = "air.execute"() ({
      "func.call"(%arg17) <{callee = @kernel}> : (memref<4xi32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) {id = 3 : i32} : () -> !air.async.token
    %30 = "air.dma_memcpy_nd"(%29, %arg18, %arg17) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 2 : i32} : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "dma_then_call"}> ({
  ^bb0(%arg15: memref<4xi32>, %arg16: memref<4xi32>):
    %27 = "air.dma_memcpy_nd"(%arg16, %arg15) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 3 : i32} : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    %28 = "air.execute"(%27) ({
      "func.call"(%arg15) <{callee = @kernel}> : (memref<4xi32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) {id = 4 : i32} : (!air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "sync_herd_body"}> ({
  ^bb0(%arg10: memref<4xi32>):
    %20 = "arith.constant"() <{value = 1 : index}> : () -> index
    %21 = "air.channel.put"(%arg10) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 1 : i32} : (memref<4xi32>) -> !air.async.token
    %22 = "air.herd"(%20, %20) <{operandSegmentSizes = array<i32: 0, 2, 0>}> ({
    ^bb0(%arg11: index, %arg12: index, %arg13: index, %arg14: index):
      %23:2 = "air.execute"() ({
        %26 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
        "air.execute_terminator"(%26) : (memref<4xi32, 2>) -> ()
      }) {id = 5 : i32} : () -> (!air.async.token, memref<4xi32, 2>)
      %24 = "air.channel.get"(%23#0, %23#1) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 2 : i32} : (!air.async.token, memref<4xi32, 2>) -> !air.async.token
      %25 = "air.execute"(%24) ({
        "memref.dealloc"(%23#1) : (memref<4xi32, 2>) -> ()
        "air.execute_terminator"() : () -> ()
      }) {id = 6 : i32} : (!air.async.token) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) {id = 1 : i32} : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<1024xi32>) -> (), sym_name = "fifo_before_loop"}> ({
  ^bb0(%arg0: memref<1024xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 8 : index}> : () -> index
    %3 = "air.channel.put"(%arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 3 : i32} : (memref<1024xi32>) -> !air.async.token
    %4 = "air.wait_all"() {id = 1 : i32} : () -> !air.async.token
    %5 = "scf.for"(%0, %2, %1, %4) ({
    ^bb0(%arg8: index, %arg9: !air.async.token):
      %18 = "air.channel.put"(%arg9, %arg0) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 4 : i32} : (!air.async.token, memref<1024xi32>) -> !air.async.token
      %19 = "air.wait_all"(%18) {id = 2 : i32} : (!air.async.token) -> !air.async.token
      "scf.yield"(%19) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    %6:2 = "air.execute"() ({
      %17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1024xi32, 2>
      "air.execute_terminator"(%17) : (memref<1024xi32, 2>) -> ()
    }) {id = 7 : i32} : () -> (!air.async.token, memref<1024xi32, 2>)
    %7 = "air.herd"(%6#0, %1, %1, %6#1) <{operandSegmentSizes = array<i32: 1, 2, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: index, %arg4: index, %arg5: memref<1024xi32, 2>):
      %9 = "arith.constant"() <{value = 0 : index}> : () -> index
      %10 = "arith.constant"() <{value = 1 : index}> : () -> index
      %11 = "arith.constant"() <{value = 8 : index}> : () -> index
      %12 = "air.channel.get"(%arg5) <{chan_name = @C, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 5 : i32} : (memref<1024xi32, 2>) -> !air.async.token
      %13 = "air.wait_all"(%12) {id = 3 : i32} : (!air.async.token) -> !air.async.token
      %14 = "scf.for"(%9, %11, %10, %13) ({
      ^bb0(%arg6: index, %arg7: !air.async.token):
        %15 = "air.channel.get"(%arg7, %arg5) <{chan_name = @C, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 6 : i32} : (!air.async.token, memref<1024xi32, 2>) -> !air.async.token
        %16 = "air.wait_all"(%15) {id = 4 : i32} : (!air.async.token) -> !air.async.token
        "scf.yield"(%16) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) {id = 2 : i32} : (!air.async.token, index, index, memref<1024xi32, 2>) -> !air.async.token
    %8 = "air.execute"(%7) ({
      "memref.dealloc"(%6#1) : (memref<1024xi32, 2>) -> ()
      "air.execute_terminator"() : () -> ()
    }) {id = 8 : i32} : (!air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
