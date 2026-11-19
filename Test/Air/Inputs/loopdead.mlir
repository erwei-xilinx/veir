"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "ca"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "aligned"}> ({
  ^bb0(%arg59: index):
    %68 = "arith.constant"() <{value = 1 : index}> : () -> index
    %69 = "air.launch"(%68, %arg59) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg60: index, %arg61: index, %arg62: index):
      %70 = "air.segment"(%arg62) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg63: index):
        %71 = "arith.constant"() <{value = 0 : index}> : () -> index
        %72 = "arith.constant"() <{value = 1 : index}> : () -> index
        %73:2 = "air.execute"() ({
          %83 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%83) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %74 = "scf.for"(%71, %arg63, %72, %73#0) ({
        ^bb0(%arg71: index, %arg72: !air.async.token):
          %82 = "air.channel.put"(%arg72, %73#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%82) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %75 = "air.herd"(%72, %72, %arg63) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg64: index, %arg65: index, %arg66: index, %arg67: index, %arg68: index):
          %76 = "arith.constant"() <{value = 0 : index}> : () -> index
          %77 = "arith.constant"() <{value = 1 : index}> : () -> index
          %78:2 = "air.execute"() ({
            %81 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%81) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %79 = "scf.for"(%76, %arg68, %77, %78#0) ({
          ^bb0(%arg69: index, %arg70: !air.async.token):
            %80 = "air.channel.get"(%arg70, %78#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%80) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "multiple"}> ({
  ^bb0(%arg45: index):
    %49 = "arith.constant"() <{value = 1 : index}> : () -> index
    %50 = "air.launch"(%49, %arg45) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg46: index, %arg47: index, %arg48: index):
      %51 = "air.segment"(%arg48) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg49: index):
        %52 = "arith.constant"() <{value = 0 : index}> : () -> index
        %53 = "arith.constant"() <{value = 1 : index}> : () -> index
        %54:2 = "air.execute"() ({
          %67 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%67) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %55 = "scf.for"(%52, %arg49, %53, %54#0) ({
        ^bb0(%arg57: index, %arg58: !air.async.token):
          %66 = "air.channel.put"(%arg58, %54#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%66) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %56 = "air.herd"(%53, %53, %arg49) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg50: index, %arg51: index, %arg52: index, %arg53: index, %arg54: index):
          %57 = "arith.constant"() <{value = 0 : index}> : () -> index
          %58 = "arith.constant"() <{value = 1 : index}> : () -> index
          %59:2 = "air.execute"() ({
            %65 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%65) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %60 = "arith.constant"() <{value = 4 : index}> : () -> index
          %61 = "arith.constant"() <{value = 8 : index}> : () -> index
          %62 = "arith.muli"(%arg54, %60) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
          %63 = "scf.for"(%57, %62, %58, %59#0) ({
          ^bb0(%arg55: index, %arg56: !air.async.token):
            %64 = "air.channel.get"(%arg56, %59#1, %57, %61, %58) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%64) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "gets_after_puts"}> ({
  ^bb0(%arg31: index):
    %33 = "arith.constant"() <{value = 1 : index}> : () -> index
    %34 = "air.launch"(%33, %arg31) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg32: index, %arg33: index, %arg34: index):
      %35 = "air.segment"(%arg34) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg35: index):
        %36 = "arith.constant"() <{value = 0 : index}> : () -> index
        %37 = "arith.constant"() <{value = 1 : index}> : () -> index
        %38:2 = "air.execute"() ({
          %48 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%48) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %39 = "scf.for"(%36, %arg35, %37, %38#0) ({
        ^bb0(%arg43: index, %arg44: !air.async.token):
          %47 = "air.channel.put"(%arg44, %38#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%47) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %40 = "air.herd"(%39, %37, %37, %arg35) <{operandSegmentSizes = array<i32: 1, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg36: index, %arg37: index, %arg38: index, %arg39: index, %arg40: index):
          %41 = "arith.constant"() <{value = 0 : index}> : () -> index
          %42 = "arith.constant"() <{value = 1 : index}> : () -> index
          %43:2 = "air.execute"() ({
            %46 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%46) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %44 = "scf.for"(%41, %arg40, %42, %43#0) ({
          ^bb0(%arg41: index, %arg42: !air.async.token):
            %45 = "air.channel.get"(%arg42, %43#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%45) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (!air.async.token, index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index, index) -> (), sym_name = "other_bound"}> ({
  ^bb0(%arg14: index, %arg15: index):
    %17 = "arith.constant"() <{value = 1 : index}> : () -> index
    %18 = "air.launch"(%17, %arg14, %arg15) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg16: index, %arg17: index, %arg18: index, %arg19: index):
      %19 = "air.segment"(%arg18, %arg19) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg20: index, %arg21: index):
        %20 = "arith.constant"() <{value = 0 : index}> : () -> index
        %21 = "arith.constant"() <{value = 1 : index}> : () -> index
        %22:2 = "air.execute"() ({
          %32 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%32) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %23 = "scf.for"(%20, %arg20, %21, %22#0) ({
        ^bb0(%arg29: index, %arg30: !air.async.token):
          %31 = "air.channel.put"(%arg30, %22#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%31) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %24 = "air.herd"(%21, %21, %arg21) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg22: index, %arg23: index, %arg24: index, %arg25: index, %arg26: index):
          %25 = "arith.constant"() <{value = 0 : index}> : () -> index
          %26 = "arith.constant"() <{value = 1 : index}> : () -> index
          %27:2 = "air.execute"() ({
            %30 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%30) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %28 = "scf.for"(%25, %arg26, %26, %27#0) ({
          ^bb0(%arg27: index, %arg28: !air.async.token):
            %29 = "air.channel.get"(%arg28, %27#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%29) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index, index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "unbalanced"}> ({
  ^bb0(%arg0: index):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "air.launch"(%0, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: index):
      %2 = "air.segment"(%arg3) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg4: index):
        %3 = "arith.constant"() <{value = 0 : index}> : () -> index
        %4 = "arith.constant"() <{value = 1 : index}> : () -> index
        %5:2 = "air.execute"() ({
          %16 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%16) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %6 = "scf.for"(%3, %arg4, %4, %5#0) ({
        ^bb0(%arg12: index, %arg13: !air.async.token):
          %15 = "air.channel.put"(%arg13, %5#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%15) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %7 = "air.herd"(%4, %4, %arg4) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg5: index, %arg6: index, %arg7: index, %arg8: index, %arg9: index):
          %8 = "arith.constant"() <{value = 0 : index}> : () -> index
          %9 = "arith.constant"() <{value = 1 : index}> : () -> index
          %10:2 = "air.execute"() ({
            %14 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%14) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %11 = "scf.for"(%8, %arg9, %9, %10#0) ({
          ^bb0(%arg10: index, %arg11: !air.async.token):
            %12 = "arith.constant"() <{value = 16 : index}> : () -> index
            %13 = "air.channel.get"(%arg11, %10#1, %8, %12, %9) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%13) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
