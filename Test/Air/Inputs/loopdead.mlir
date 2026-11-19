"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "ca"}> : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "aligned"}> ({
  ^bb0(%arg72: index):
    %88 = "arith.constant"() <{value = 1 : index}> : () -> index
    %89 = "air.launch"(%88, %arg72) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg73: index, %arg74: index, %arg75: index):
      %90 = "air.segment"(%arg75) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg76: index):
        %91 = "arith.constant"() <{value = 0 : index}> : () -> index
        %92 = "arith.constant"() <{value = 1 : index}> : () -> index
        %93:2 = "air.execute"() ({
          %103 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%103) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %94 = "scf.for"(%91, %arg76, %92, %93#0) ({
        ^bb0(%arg84: index, %arg85: !air.async.token):
          %102 = "air.channel.put"(%arg85, %93#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%102) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %95 = "air.herd"(%92, %92, %arg76) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg77: index, %arg78: index, %arg79: index, %arg80: index, %arg81: index):
          %96 = "arith.constant"() <{value = 0 : index}> : () -> index
          %97 = "arith.constant"() <{value = 1 : index}> : () -> index
          %98:2 = "air.execute"() ({
            %101 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%101) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %99 = "scf.for"(%96, %arg81, %97, %98#0) ({
          ^bb0(%arg82: index, %arg83: !air.async.token):
            %100 = "air.channel.get"(%arg83, %98#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%100) : (!air.async.token) -> ()
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
  ^bb0(%arg58: index):
    %69 = "arith.constant"() <{value = 1 : index}> : () -> index
    %70 = "air.launch"(%69, %arg58) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg59: index, %arg60: index, %arg61: index):
      %71 = "air.segment"(%arg61) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg62: index):
        %72 = "arith.constant"() <{value = 0 : index}> : () -> index
        %73 = "arith.constant"() <{value = 1 : index}> : () -> index
        %74:2 = "air.execute"() ({
          %87 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%87) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %75 = "scf.for"(%72, %arg62, %73, %74#0) ({
        ^bb0(%arg70: index, %arg71: !air.async.token):
          %86 = "air.channel.put"(%arg71, %74#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%86) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %76 = "air.herd"(%73, %73, %arg62) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg63: index, %arg64: index, %arg65: index, %arg66: index, %arg67: index):
          %77 = "arith.constant"() <{value = 0 : index}> : () -> index
          %78 = "arith.constant"() <{value = 1 : index}> : () -> index
          %79:2 = "air.execute"() ({
            %85 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%85) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %80 = "arith.constant"() <{value = 4 : index}> : () -> index
          %81 = "arith.constant"() <{value = 8 : index}> : () -> index
          %82 = "arith.muli"(%arg67, %80) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
          %83 = "scf.for"(%77, %82, %78, %79#0) ({
          ^bb0(%arg68: index, %arg69: !air.async.token):
            %84 = "air.channel.get"(%arg69, %79#1, %77, %81, %78) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%84) : (!air.async.token) -> ()
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
  ^bb0(%arg44: index):
    %53 = "arith.constant"() <{value = 1 : index}> : () -> index
    %54 = "air.launch"(%53, %arg44) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg45: index, %arg46: index, %arg47: index):
      %55 = "air.segment"(%arg47) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg48: index):
        %56 = "arith.constant"() <{value = 0 : index}> : () -> index
        %57 = "arith.constant"() <{value = 1 : index}> : () -> index
        %58:2 = "air.execute"() ({
          %68 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%68) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %59 = "scf.for"(%56, %arg48, %57, %58#0) ({
        ^bb0(%arg56: index, %arg57: !air.async.token):
          %67 = "air.channel.put"(%arg57, %58#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%67) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %60 = "air.herd"(%59, %57, %57, %arg48) <{operandSegmentSizes = array<i32: 1, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg49: index, %arg50: index, %arg51: index, %arg52: index, %arg53: index):
          %61 = "arith.constant"() <{value = 0 : index}> : () -> index
          %62 = "arith.constant"() <{value = 1 : index}> : () -> index
          %63:2 = "air.execute"() ({
            %66 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%66) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %64 = "scf.for"(%61, %arg53, %62, %63#0) ({
          ^bb0(%arg54: index, %arg55: !air.async.token):
            %65 = "air.channel.get"(%arg55, %63#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%65) : (!air.async.token) -> ()
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
  ^bb0(%arg27: index, %arg28: index):
    %37 = "arith.constant"() <{value = 1 : index}> : () -> index
    %38 = "air.launch"(%37, %arg27, %arg28) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg29: index, %arg30: index, %arg31: index, %arg32: index):
      %39 = "air.segment"(%arg31, %arg32) <{operandSegmentSizes = array<i32: 0, 0, 2>, sym_name = "seg"}> ({
      ^bb0(%arg33: index, %arg34: index):
        %40 = "arith.constant"() <{value = 0 : index}> : () -> index
        %41 = "arith.constant"() <{value = 1 : index}> : () -> index
        %42:2 = "air.execute"() ({
          %52 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%52) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %43 = "scf.for"(%40, %arg33, %41, %42#0) ({
        ^bb0(%arg42: index, %arg43: !air.async.token):
          %51 = "air.channel.put"(%arg43, %42#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%51) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %44 = "air.herd"(%41, %41, %arg34) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg35: index, %arg36: index, %arg37: index, %arg38: index, %arg39: index):
          %45 = "arith.constant"() <{value = 0 : index}> : () -> index
          %46 = "arith.constant"() <{value = 1 : index}> : () -> index
          %47:2 = "air.execute"() ({
            %50 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%50) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %48 = "scf.for"(%45, %arg39, %46, %47#0) ({
          ^bb0(%arg40: index, %arg41: !air.async.token):
            %49 = "air.channel.get"(%arg41, %47#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 2>) -> !air.async.token
            "scf.yield"(%49) : (!air.async.token) -> ()
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
  ^bb0(%arg13: index):
    %20 = "arith.constant"() <{value = 1 : index}> : () -> index
    %21 = "air.launch"(%20, %arg13) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg14: index, %arg15: index, %arg16: index):
      %22 = "air.segment"(%arg16) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg17: index):
        %23 = "arith.constant"() <{value = 0 : index}> : () -> index
        %24 = "arith.constant"() <{value = 1 : index}> : () -> index
        %25:2 = "air.execute"() ({
          %36 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%36) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %26 = "scf.for"(%23, %arg17, %24, %25#0) ({
        ^bb0(%arg25: index, %arg26: !air.async.token):
          %35 = "air.channel.put"(%arg26, %25#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%35) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        %27 = "air.herd"(%24, %24, %arg17) <{operandSegmentSizes = array<i32: 0, 2, 1>, sym_name = "herd"}> ({
        ^bb0(%arg18: index, %arg19: index, %arg20: index, %arg21: index, %arg22: index):
          %28 = "arith.constant"() <{value = 0 : index}> : () -> index
          %29 = "arith.constant"() <{value = 1 : index}> : () -> index
          %30:2 = "air.execute"() ({
            %34 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 2>
            "air.execute_terminator"(%34) : (memref<32xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<32xi32, 2>)
          %31 = "scf.for"(%28, %arg22, %29, %30#0) ({
          ^bb0(%arg23: index, %arg24: !air.async.token):
            %32 = "arith.constant"() <{value = 16 : index}> : () -> index
            %33 = "air.channel.get"(%arg24, %30#1, %28, %32, %29) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<32xi32, 2>, index, index, index) -> !air.async.token
            "scf.yield"(%33) : (!air.async.token) -> ()
          }) : (index, index, index, !air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4096xi32>, memref<4096xi32>, index) -> (), sym_name = "dma_nest"}> ({
  ^bb0(%arg7: memref<4096xi32>, %arg8: memref<4096xi32>, %arg9: index):
    %13 = "arith.constant"() <{value = 0 : index}> : () -> index
    %14 = "arith.constant"() <{value = 1 : index}> : () -> index
    %15 = "arith.constant"() <{value = 8 : index}> : () -> index
    "scf.for"(%13, %arg9, %14) ({
    ^bb0(%arg10: index):
      %16 = "arith.muli"(%arg10, %15) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %17 = "air.wait_all"() : () -> !air.async.token
      %18 = "scf.for"(%13, %arg9, %14, %17) ({
      ^bb0(%arg11: index, %arg12: !air.async.token):
        %19 = "air.dma_memcpy_nd"(%arg12, %arg8, %16, %15, %14, %arg7, %16, %15, %14) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<4096xi32>, index, index, index, memref<4096xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%19) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "put_after_get"}> ({
  ^bb0(%arg0: index):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "air.launch"(%0, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: index):
      %2 = "air.segment"(%arg3) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg4: index):
        %3 = "arith.constant"() <{value = 0 : index}> : () -> index
        %4 = "arith.constant"() <{value = 1 : index}> : () -> index
        %5:2 = "air.execute"() ({
          %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%12) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %6:2 = "air.execute"() ({
          %11 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<32xi32, 1>
          "air.execute_terminator"(%11) : (memref<32xi32, 1>) -> ()
        }) : () -> (!air.async.token, memref<32xi32, 1>)
        %7 = "air.wait_all"(%5#0, %6#0) : (!air.async.token, !air.async.token) -> !air.async.token
        %8 = "scf.for"(%3, %arg4, %4, %7) ({
        ^bb0(%arg5: index, %arg6: !air.async.token):
          %9 = "air.channel.get"(%arg6, %6#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          %10 = "air.channel.put"(%9, %5#1) <{chan_name = @ca, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<32xi32, 1>) -> !air.async.token
          "scf.yield"(%10) : (!air.async.token) -> ()
        }) : (index, index, index, !air.async.token) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
