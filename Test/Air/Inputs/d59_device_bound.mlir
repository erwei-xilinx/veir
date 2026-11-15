"builtin.module"() ({
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "device_bound"}> ({
  ^bb0(%arg20: memref<1xi32>, %arg21: memref<8xi32>):
    %24 = "arith.constant"() <{value = 0 : index}> : () -> index
    %25 = "arith.constant"() <{value = 1 : index}> : () -> index
    %26 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %27:2 = "air.execute"() ({
      %28 = "memref.load"(%arg20, %24) : (memref<1xi32>, index) -> i32
      %29 = "arith.index_cast"(%28) : (i32) -> index
      "air.execute_terminator"(%29) : (index) -> ()
    }) : () -> (!air.async.token, index)
    "air.wait_all"(%27#0) : (!air.async.token) -> ()
    "scf.for"(%24, %27#1, %25) ({
    ^bb0(%arg22: index):
      "memref.store"(%26, %arg21, %arg22) : (i32, memref<8xi32>, index) -> ()
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "unordered_bound"}> ({
  ^bb0(%arg17: memref<1xi32>, %arg18: memref<8xi32>):
    %18 = "arith.constant"() <{value = 0 : index}> : () -> index
    %19 = "arith.constant"() <{value = 1 : index}> : () -> index
    %20 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %21:2 = "air.execute"() ({
      %22 = "memref.load"(%arg17, %18) : (memref<1xi32>, index) -> i32
      %23 = "arith.index_cast"(%22) : (i32) -> index
      "air.execute_terminator"(%23) : (index) -> ()
    }) : () -> (!air.async.token, index)
    "scf.for"(%18, %21#1, %19) ({
    ^bb0(%arg19: index):
      "memref.store"(%20, %arg18, %arg19) : (i32, memref<8xi32>, index) -> ()
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "device_branch"}> ({
  ^bb0(%arg15: memref<1xi32>, %arg16: memref<8xi32>):
    %11 = "arith.constant"() <{value = 0 : index}> : () -> index
    %12 = "arith.constant"() <{value = 5 : i32}> : () -> i32
    %13 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %14 = "arith.constant"() <{value = 9 : i32}> : () -> i32
    %15:2 = "air.execute"() ({
      %16 = "memref.load"(%arg15, %11) : (memref<1xi32>, index) -> i32
      %17 = "arith.cmpi"(%16, %12) <{predicate = 4 : i64}> : (i32, i32) -> i1
      "air.execute_terminator"(%17) : (i1) -> ()
    }) : () -> (!air.async.token, i1)
    "air.wait_all"(%15#0) : (!air.async.token) -> ()
    "scf.if"(%15#1) ({
      "memref.store"(%14, %arg16, %11) : (i32, memref<8xi32>, index) -> ()
      "scf.yield"() : () -> ()
    }, {
      "memref.store"(%13, %arg16, %11) : (i32, memref<8xi32>, index) -> ()
      "scf.yield"() : () -> ()
    }) : (i1) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "cnt"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "res"}> : () -> ()
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "channel_bound"}> ({
  ^bb0(%arg0: memref<1xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: index, %arg5: index, %arg6: memref<1xi32>, %arg7: memref<8xi32>):
      %1 = "air.segment"(%arg7) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "s"}> ({
      ^bb0(%arg8: memref<8xi32>):
        %2 = "arith.constant"() <{value = 1 : index}> : () -> index
        "air.herd"(%2, %2, %arg8) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "h"}> ({
        ^bb0(%arg9: index, %arg10: index, %arg11: index, %arg12: index, %arg13: memref<8xi32>):
          %3 = "arith.constant"() <{value = 0 : index}> : () -> index
          %4 = "arith.constant"() <{value = 1 : index}> : () -> index
          %5 = "arith.constant"() <{value = 7 : i32}> : () -> i32
          %6 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32, 2>
          "air.channel.get"(%6) <{chan_name = @cnt, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1xi32, 2>) -> ()
          %7:2 = "air.execute"() ({
            %9 = "memref.load"(%6, %3) : (memref<1xi32, 2>, index) -> i32
            %10 = "arith.index_cast"(%9) : (i32) -> index
            "air.execute_terminator"(%10) : (index) -> ()
          }) : () -> (!air.async.token, index)
          %8 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32, 2>
          "air.wait_all"(%7#0) : (!air.async.token) -> ()
          "scf.for"(%3, %7#1, %4) ({
          ^bb0(%arg14: index):
            "memref.store"(%5, %8, %arg14) : (i32, memref<8xi32, 2>, index) -> ()
            "scf.yield"() : () -> ()
          }) : (index, index, index) -> ()
          "air.channel.put"(%8) <{chan_name = @res, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32, 2>) -> ()
          "memref.dealloc"(%8) : (memref<8xi32, 2>) -> ()
          "memref.dealloc"(%6) : (memref<1xi32, 2>) -> ()
          "air.herd_terminator"() : () -> ()
        }) : (index, index, memref<8xi32>) -> ()
        "air.segment_terminator"() : () -> ()
      }) : (memref<8xi32>) -> !air.async.token
      "air.channel.put"(%arg6) <{chan_name = @cnt, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1xi32>) -> ()
      "air.channel.get"(%arg7) <{chan_name = @res, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32>) -> ()
      "air.wait_all"(%1) : (!air.async.token) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, index, memref<1xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
