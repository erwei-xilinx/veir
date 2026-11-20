"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "switch_both_sides"}> ({
  ^bb0(%arg11: index):
    %33 = "arith.constant"() <{value = 1 : index}> : () -> index
    %34 = "air.launch"(%33, %arg11) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg12: index, %arg13: index, %arg14: index):
      %35 = "air.segment"(%arg14) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg15: index):
        %36 = "arith.constant"() <{value = 1 : index}> : () -> index
        %37:2 = "air.execute"() ({
          %51 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%51) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %38 = "scf.index_switch"(%arg15) <{cases = array<i64: 0, 1>}> ({
          "scf.yield"(%37#0) : (!air.async.token) -> ()
        }, {
          %50 = "air.channel.put"(%37#0, %37#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%50) : (!air.async.token) -> ()
        }, {
          %49 = "air.channel.put"(%37#0, %37#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%49) : (!air.async.token) -> ()
        }) : (index) -> !air.async.token
        %39 = "air.herd"(%36, %36, %arg15) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg16: index, %arg17: index, %arg18: index, %arg19: index, %arg20: index):
          %40:2 = "air.execute"() ({
            %48 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%48) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %41 = "arith.constant"() <{value = 0 : index}> : () -> index
          %42 = "arith.constant"() <{value = 2 : index}> : () -> index
          %43 = "arith.cmpi"(%arg20, %42) <{predicate = 2 : i64}> : (index, index) -> i1
          %44 = "arith.cmpi"(%arg20, %41) <{predicate = 5 : i64}> : (index, index) -> i1
          %45 = "arith.andi"(%43, %44) : (i1, i1) -> i1
          %46 = "scf.if"(%45) ({
            %47 = "air.channel.get"(%40#0, %40#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%47) : (!air.async.token) -> ()
          }, {
            "scf.yield"(%40#0) : (!air.async.token) -> ()
          }) : (i1) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (i1) -> (), sym_name = "flag"}> ({
  ^bb0(%arg6: i1):
    %21 = "arith.constant"() <{value = 1 : index}> : () -> index
    %22 = "air.launch"(%21, %arg6) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg7: index, %arg8: index, %arg9: i1):
      %23 = "air.segment"(%arg9) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg10: i1):
        %24 = "arith.constant"() <{value = 1 : index}> : () -> index
        %25:2 = "air.execute"() ({
          %32 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%32) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %26:2 = "air.execute"() ({
          %31 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%31) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %27 = "scf.if"(%arg10) ({
          %28 = "air.channel.put"(%25#0, %25#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %29 = "air.channel.get"(%26#0, %26#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %30 = "air.wait_all"(%28, %29) : (!air.async.token, !air.async.token) -> !air.async.token
          "scf.yield"(%30) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%25#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i1) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i1) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (i32) -> (), sym_name = "one_side_guarded"}> ({
  ^bb0(%arg1: i32):
    %8 = "arith.constant"() <{value = 1 : index}> : () -> index
    %9 = "air.launch"(%8, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: i32):
      %10 = "air.segment"(%arg4) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg5: i32):
        %11 = "arith.constant"() <{value = 1 : index}> : () -> index
        %12 = "arith.constant"() <{value = 4 : i32}> : () -> i32
        %13:2 = "air.execute"() ({
          %20 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%20) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %14:2 = "air.execute"() ({
          %19 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%19) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %15 = "arith.cmpi"(%arg5, %12) <{predicate = 2 : i64}> : (i32, i32) -> i1
        %16 = "scf.if"(%15) ({
          %18 = "air.channel.put"(%13#0, %13#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%18) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%13#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        %17 = "air.channel.get"(%14#0, %14#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i32) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i32) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "also_offset"}> ({
  ^bb0(%arg0: index):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "arith.constant"() <{value = 0 : index}> : () -> index
    %2 = "arith.constant"() <{value = 8 : index}> : () -> index
    %3 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<64xi32>
    %4 = "air.wait_all"() : () -> !air.async.token
    %5 = "arith.cmpi"(%arg0, %1) <{predicate = 4 : i64}> : (index, index) -> i1
    %6 = "scf.if"(%5) ({
      %7 = "air.channel.put"(%4, %3, %arg0, %2, %0) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index) -> !air.async.token
      "scf.yield"(%7) : (!air.async.token) -> ()
    }, {
      "scf.yield"(%4) : (!air.async.token) -> ()
    }) : (i1) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
