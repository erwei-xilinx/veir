"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "switch_both_sides"}> ({
  ^bb0(%arg13: index):
    %50 = "arith.constant"() <{value = 1 : index}> : () -> index
    %51 = "air.launch"(%50, %arg13) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg14: index, %arg15: index, %arg16: index):
      %52 = "air.segment"(%arg16) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg17: index):
        %53 = "arith.constant"() <{value = 1 : index}> : () -> index
        %54:2 = "air.execute"() ({
          %68 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%68) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %55 = "scf.index_switch"(%arg17) <{cases = array<i64: 0, 1>}> ({
          "scf.yield"(%54#0) : (!air.async.token) -> ()
        }, {
          %67 = "air.channel.put"(%54#0, %54#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%67) : (!air.async.token) -> ()
        }, {
          %66 = "air.channel.put"(%54#0, %54#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%66) : (!air.async.token) -> ()
        }) : (index) -> !air.async.token
        %56 = "air.herd"(%53, %53, %arg17) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg18: index, %arg19: index, %arg20: index, %arg21: index, %arg22: index):
          %57:2 = "air.execute"() ({
            %65 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%65) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %58 = "arith.constant"() <{value = 0 : index}> : () -> index
          %59 = "arith.constant"() <{value = 2 : index}> : () -> index
          %60 = "arith.cmpi"(%arg22, %59) <{predicate = 2 : i64}> : (index, index) -> i1
          %61 = "arith.cmpi"(%arg22, %58) <{predicate = 5 : i64}> : (index, index) -> i1
          %62 = "arith.andi"(%60, %61) : (i1, i1) -> i1
          %63 = "scf.if"(%62) ({
            %64 = "air.channel.get"(%57#0, %57#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%64) : (!air.async.token) -> ()
          }, {
            "scf.yield"(%57#0) : (!air.async.token) -> ()
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
  ^bb0(%arg8: i1):
    %38 = "arith.constant"() <{value = 1 : index}> : () -> index
    %39 = "air.launch"(%38, %arg8) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg9: index, %arg10: index, %arg11: i1):
      %40 = "air.segment"(%arg11) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg12: i1):
        %41 = "arith.constant"() <{value = 1 : index}> : () -> index
        %42:2 = "air.execute"() ({
          %49 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%49) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %43:2 = "air.execute"() ({
          %48 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%48) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %44 = "scf.if"(%arg12) ({
          %45 = "air.channel.put"(%42#0, %42#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %46 = "air.channel.get"(%43#0, %43#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %47 = "air.wait_all"(%45, %46) : (!air.async.token, !air.async.token) -> !air.async.token
          "scf.yield"(%47) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%42#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i1) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i1) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (i32) -> (), sym_name = "one_side_guarded"}> ({
  ^bb0(%arg3: i32):
    %25 = "arith.constant"() <{value = 1 : index}> : () -> index
    %26 = "air.launch"(%25, %arg3) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg4: index, %arg5: index, %arg6: i32):
      %27 = "air.segment"(%arg6) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg7: i32):
        %28 = "arith.constant"() <{value = 1 : index}> : () -> index
        %29 = "arith.constant"() <{value = 4 : i32}> : () -> i32
        %30:2 = "air.execute"() ({
          %37 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%37) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %31:2 = "air.execute"() ({
          %36 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%36) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %32 = "arith.cmpi"(%arg7, %29) <{predicate = 2 : i64}> : (i32, i32) -> i1
        %33 = "scf.if"(%32) ({
          %35 = "air.channel.put"(%30#0, %30#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%35) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%30#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        %34 = "air.channel.get"(%31#0, %31#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i32) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i32) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "offset_arg"}> ({
  ^bb0(%arg2: index):
    %18 = "arith.constant"() <{value = 1 : index}> : () -> index
    %19 = "arith.constant"() <{value = 8 : index}> : () -> index
    %20 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<64xi32>
    %21 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    %22 = "air.wait_all"() : () -> !air.async.token
    %23 = "air.channel.put"(%22, %21) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>) -> !air.async.token
    %24 = "air.channel.get"(%22, %20, %arg2, %19, %18) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index) -> !air.async.token
    "air.wait_all"(%23, %24) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "offset_arg_overlap"}> ({
  ^bb0(%arg1: index):
    %8 = "arith.constant"() <{value = 0 : index}> : () -> index
    %9 = "arith.constant"() <{value = 1 : index}> : () -> index
    %10 = "arith.constant"() <{value = 8 : index}> : () -> index
    %11 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<64xi32>
    %13 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    %14 = "air.wait_all"() : () -> !air.async.token
    %15 = "air.channel.put"(%14, %13) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>) -> !air.async.token
    %16 = "air.channel.get"(%14, %12, %arg1, %10, %9) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index) -> !air.async.token
    %17 = "air.execute"(%14) ({
      "memref.store"(%11, %12, %8) : (i32, memref<64xi32>, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : (!air.async.token) -> !air.async.token
    "air.wait_all"(%15, %16, %17) : (!air.async.token, !air.async.token, !air.async.token) -> ()
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
