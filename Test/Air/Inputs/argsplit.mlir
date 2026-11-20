"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "c"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "switch_both_sides"}> ({
  ^bb0(%arg14: index):
    %55 = "arith.constant"() <{value = 1 : index}> : () -> index
    %56 = "air.launch"(%55, %arg14) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg15: index, %arg16: index, %arg17: index):
      %57 = "air.segment"(%arg17) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg18: index):
        %58 = "arith.constant"() <{value = 1 : index}> : () -> index
        %59:2 = "air.execute"() ({
          %73 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%73) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %60 = "scf.index_switch"(%arg18) <{cases = array<i64: 0, 1>}> ({
          "scf.yield"(%59#0) : (!air.async.token) -> ()
        }, {
          %72 = "air.channel.put"(%59#0, %59#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%72) : (!air.async.token) -> ()
        }, {
          %71 = "air.channel.put"(%59#0, %59#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%71) : (!air.async.token) -> ()
        }) : (index) -> !air.async.token
        %61 = "air.herd"(%58, %58, %arg18) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg19: index, %arg20: index, %arg21: index, %arg22: index, %arg23: index):
          %62:2 = "air.execute"() ({
            %70 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%70) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %63 = "arith.constant"() <{value = 0 : index}> : () -> index
          %64 = "arith.constant"() <{value = 2 : index}> : () -> index
          %65 = "arith.cmpi"(%arg23, %64) <{predicate = 2 : i64}> : (index, index) -> i1
          %66 = "arith.cmpi"(%arg23, %63) <{predicate = 5 : i64}> : (index, index) -> i1
          %67 = "arith.andi"(%65, %66) : (i1, i1) -> i1
          %68 = "scf.if"(%67) ({
            %69 = "air.channel.get"(%62#0, %62#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%69) : (!air.async.token) -> ()
          }, {
            "scf.yield"(%62#0) : (!air.async.token) -> ()
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
  ^bb0(%arg9: i1):
    %43 = "arith.constant"() <{value = 1 : index}> : () -> index
    %44 = "air.launch"(%43, %arg9) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg10: index, %arg11: index, %arg12: i1):
      %45 = "air.segment"(%arg12) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg13: i1):
        %46 = "arith.constant"() <{value = 1 : index}> : () -> index
        %47:2 = "air.execute"() ({
          %54 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%54) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %48:2 = "air.execute"() ({
          %53 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%53) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %49 = "scf.if"(%arg13) ({
          %50 = "air.channel.put"(%47#0, %47#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %51 = "air.channel.get"(%48#0, %48#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %52 = "air.wait_all"(%50, %51) : (!air.async.token, !air.async.token) -> !air.async.token
          "scf.yield"(%52) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%47#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i1) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i1) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (i32) -> (), sym_name = "one_side_guarded"}> ({
  ^bb0(%arg4: i32):
    %30 = "arith.constant"() <{value = 1 : index}> : () -> index
    %31 = "air.launch"(%30, %arg4) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg5: index, %arg6: index, %arg7: i32):
      %32 = "air.segment"(%arg7) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg8: i32):
        %33 = "arith.constant"() <{value = 1 : index}> : () -> index
        %34 = "arith.constant"() <{value = 4 : i32}> : () -> i32
        %35:2 = "air.execute"() ({
          %42 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%42) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %36:2 = "air.execute"() ({
          %41 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%41) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %37 = "arith.cmpi"(%arg8, %34) <{predicate = 2 : i64}> : (i32, i32) -> i1
        %38 = "scf.if"(%37) ({
          %40 = "air.channel.put"(%35#0, %35#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%40) : (!air.async.token) -> ()
        }, {
          "scf.yield"(%35#0) : (!air.async.token) -> ()
        }) : (i1) -> !air.async.token
        %39 = "air.channel.get"(%36#0, %36#1) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (i32) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, i32) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "offset_arg"}> ({
  ^bb0(%arg3: index):
    %23 = "arith.constant"() <{value = 1 : index}> : () -> index
    %24 = "arith.constant"() <{value = 8 : index}> : () -> index
    %25 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<64xi32>
    %26 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    %27 = "air.wait_all"() : () -> !air.async.token
    %28 = "air.channel.put"(%27, %26) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>) -> !air.async.token
    %29 = "air.channel.get"(%27, %25, %arg3, %24, %23) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index) -> !air.async.token
    "air.wait_all"(%28, %29) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "offset_arg_overlap"}> ({
  ^bb0(%arg2: index):
    %13 = "arith.constant"() <{value = 0 : index}> : () -> index
    %14 = "arith.constant"() <{value = 1 : index}> : () -> index
    %15 = "arith.constant"() <{value = 8 : index}> : () -> index
    %16 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<64xi32>
    %18 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    %19 = "air.wait_all"() : () -> !air.async.token
    %20 = "air.channel.put"(%19, %18) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>) -> !air.async.token
    %21 = "air.channel.get"(%19, %17, %arg2, %15, %14) <{chan_name = @c, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index) -> !air.async.token
    %22 = "air.execute"(%19) ({
      "memref.store"(%16, %17, %13) : (i32, memref<64xi32>, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : (!air.async.token) -> !air.async.token
    "air.wait_all"(%20, %21, %22) : (!air.async.token, !air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "size_arg"}> ({
  ^bb0(%arg1: index):
    %8 = "arith.constant"() <{value = 0 : index}> : () -> index
    %9 = "arith.constant"() <{value = 1 : index}> : () -> index
    %10 = "arith.constant"() <{value = 8 : index}> : () -> index
    %11 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi32>
    %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8xi32>
    "air.channel.put"(%11, %8, %8, %arg1, %10, %10, %9) <{chan_name = @c, operandSegmentSizes = array<i32: 0, 0, 1, 2, 2, 2, 0>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (memref<4x8xi32>, index, index, index, index, index, index) -> ()
    "air.channel.get"(%12) <{chan_name = @c, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<8xi32>) -> ()
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
