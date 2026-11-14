"builtin.module"() ({
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1], sym_name = "drain"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1], sym_name = "feed"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [2, 2], sym_name = "T"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [2], sym_name = "L"}> : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [2], sym_name = "R"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "drain_dep"}> ({
  ^bb0(%arg73: memref<4xi32>, %arg74: memref<4xi32>):
    %63 = "arith.constant"() <{value = 1 : index}> : () -> index
    %64 = "air.launch"(%63, %arg73, %arg74) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg75: index, %arg76: index, %arg77: memref<4xi32>, %arg78: memref<4xi32>):
      %65 = "air.channel.put"(%arg78) <{chan_name = @feed, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
      %66 = "air.segment"(%arg77) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg79: memref<4xi32>):
        %68 = "arith.constant"() <{value = 1 : index}> : () -> index
        %69 = "air.herd"(%68, %68) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg80: index, %arg81: index, %arg82: index, %arg83: index):
          %70:2 = "air.execute"() ({
            %74 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
            "air.execute_terminator"(%74) : (memref<4xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<4xi32, 2>)
          %71 = "air.channel.get"(%70#0, %70#1) <{chan_name = @feed, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32, 2>) -> !air.async.token
          %72 = "air.channel.put"(%71, %70#1) <{chan_name = @drain, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32, 2>) -> !air.async.token
          %73 = "air.execute"(%72) ({
            "memref.dealloc"(%70#1) : (memref<4xi32, 2>) -> ()
            "air.execute_terminator"() : () -> ()
          }) : (!air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> !air.async.token
      %67 = "air.channel.get"(%66, %arg77) <{chan_name = @drain, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32>) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "drain_fixed"}> ({
  ^bb0(%arg62: memref<4xi32>, %arg63: memref<4xi32>):
    %51 = "arith.constant"() <{value = 1 : index}> : () -> index
    %52 = "air.launch"(%51, %arg62, %arg63) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg64: index, %arg65: index, %arg66: memref<4xi32>, %arg67: memref<4xi32>):
      %53 = "air.channel.put"(%arg67) <{chan_name = @feed, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
      %54 = "air.segment"(%arg66) <{operandSegmentSizes = array<i32: 0, 0, 1>, sym_name = "seg"}> ({
      ^bb0(%arg68: memref<4xi32>):
        %56 = "arith.constant"() <{value = 1 : index}> : () -> index
        %57 = "air.herd"(%56, %56) <{operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "h"}> ({
        ^bb0(%arg69: index, %arg70: index, %arg71: index, %arg72: index):
          %58:2 = "air.execute"() ({
            %62 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 2>
            "air.execute_terminator"(%62) : (memref<4xi32, 2>) -> ()
          }) : () -> (!air.async.token, memref<4xi32, 2>)
          %59 = "air.channel.get"(%58#0, %58#1) <{chan_name = @feed, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, memref<4xi32, 2>) -> !air.async.token
          %60 = "air.channel.put"(%59, %58#1) <{chan_name = @drain, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32, 2>) -> !air.async.token
          %61 = "air.execute"(%60) ({
            "memref.dealloc"(%58#1) : (memref<4xi32, 2>) -> ()
            "air.execute_terminator"() : () -> ()
          }) : (!air.async.token) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) : (index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>) -> !air.async.token
      %55 = "air.channel.get"(%arg66) <{chan_name = @drain, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<4xi32>) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "herd_tiles"}> ({
  ^bb0(%arg55: memref<4xi32>, %arg56: memref<4xi32>):
    %33 = "arith.constant"() <{value = 0 : index}> : () -> index
    %34 = "arith.constant"() <{value = 1 : index}> : () -> index
    %35 = "arith.constant"() <{value = 2 : index}> : () -> index
    %36 = "arith.constant"() <{value = 3 : index}> : () -> index
    %37 = "air.channel.put"(%33, %33, %arg56, %33, %34, %34) <{chan_name = @T, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<4xi32>, index, index, index) -> !air.async.token
    %38 = "air.channel.put"(%33, %34, %arg56, %34, %34, %34) <{chan_name = @T, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<4xi32>, index, index, index) -> !air.async.token
    %39 = "air.channel.put"(%34, %33, %arg56, %35, %34, %34) <{chan_name = @T, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<4xi32>, index, index, index) -> !air.async.token
    %40 = "air.channel.put"(%34, %34, %arg56, %36, %34, %34) <{chan_name = @T, operandSegmentSizes = array<i32: 0, 2, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, index, memref<4xi32>, index, index, index) -> !air.async.token
    %41 = "air.herd"(%35, %35, %arg55) <{operandSegmentSizes = array<i32: 0, 2, 1>}> ({
    ^bb0(%arg57: index, %arg58: index, %arg59: index, %arg60: index, %arg61: memref<4xi32>):
      %42 = "arith.constant"() <{value = 0 : index}> : () -> index
      %43 = "arith.constant"() <{value = 1 : index}> : () -> index
      %44 = "arith.constant"() <{value = 2 : index}> : () -> index
      %45:2 = "air.execute"() ({
        %50 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32, 2>
        "air.execute_terminator"(%50) : (memref<1xi32, 2>) -> ()
      }) : () -> (!air.async.token, memref<1xi32, 2>)
      %46 = "air.channel.get"(%45#0, %arg57, %arg58, %45#1) <{chan_name = @T, operandSegmentSizes = array<i32: 1, 2, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (!air.async.token, index, index, memref<1xi32, 2>) -> !air.async.token
      %47 = "arith.muli"(%arg57, %44) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %48 = "arith.addi"(%47, %arg58) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %49 = "air.dma_memcpy_nd"(%46, %arg61, %48, %43, %43, %45#1) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, index, index, index, memref<1xi32, 2>) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "herd_shared_write"}> ({
  ^bb0(%arg47: memref<4xi32>, %arg48: memref<4xi32>):
    %28 = "arith.constant"() <{value = 2 : index}> : () -> index
    %29 = "air.herd"(%28, %28, %arg47, %arg48) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg49: index, %arg50: index, %arg51: index, %arg52: index, %arg53: memref<4xi32>, %arg54: memref<4xi32>):
      %30 = "arith.constant"() <{value = 0 : index}> : () -> index
      %31 = "arith.constant"() <{value = 1 : index}> : () -> index
      %32 = "air.dma_memcpy_nd"(%arg53, %30, %31, %31, %arg54, %30, %31, %31) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "sync_herd"}> ({
  ^bb0(%arg38: memref<4xi32>, %arg39: memref<4xi32>, %arg40: memref<4xi32>):
    %25 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.herd"(%25, %25, %arg38, %arg39) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg41: index, %arg42: index, %arg43: index, %arg44: index, %arg45: memref<4xi32>, %arg46: memref<4xi32>):
      %27 = "air.dma_memcpy_nd"(%arg45, %arg46) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<4xi32>, memref<4xi32>) -> ()
    %26 = "air.dma_memcpy_nd"(%arg40, %arg38) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "async_herd_unordered"}> ({
  ^bb0(%arg29: memref<4xi32>, %arg30: memref<4xi32>, %arg31: memref<4xi32>):
    %21 = "arith.constant"() <{value = 1 : index}> : () -> index
    %22 = "air.herd"(%21, %21, %arg29, %arg30) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg32: index, %arg33: index, %arg34: index, %arg35: index, %arg36: memref<4xi32>, %arg37: memref<4xi32>):
      %24 = "air.dma_memcpy_nd"(%arg36, %arg37) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    %23 = "air.dma_memcpy_nd"(%arg31, %arg29) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "token_arg"}> ({
  ^bb0(%arg19: memref<4xi32>, %arg20: memref<4xi32>, %arg21: memref<4xi32>):
    %17 = "arith.constant"() <{value = 1 : index}> : () -> index
    %18 = "air.dma_memcpy_nd"(%arg20, %arg21) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    %19 = "air.herd"(%17, %17, %arg19, %arg20, %18) <{operandSegmentSizes = array<i32: 0, 2, 3>}> ({
    ^bb0(%arg22: index, %arg23: index, %arg24: index, %arg25: index, %arg26: memref<4xi32>, %arg27: memref<4xi32>, %arg28: !air.async.token):
      %20 = "air.dma_memcpy_nd"(%arg28, %arg26, %arg27) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<4xi32>, memref<4xi32>, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "launch_talk"}> ({
  ^bb0(%arg13: memref<4xi32>, %arg14: memref<4xi32>):
    %11 = "arith.constant"() <{value = 2 : index}> : () -> index
    %12 = "air.launch"(%11, %arg13, %arg14) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg15: index, %arg16: index, %arg17: memref<4xi32>, %arg18: memref<4xi32>):
      %13 = "arith.constant"() <{value = 1 : index}> : () -> index
      %14 = "arith.subi"(%13, %arg15) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %15 = "air.channel.put"(%14, %arg18, %arg15, %13, %13) <{chan_name = @L, operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, memref<4xi32>, index, index, index) -> !air.async.token
      %16 = "air.channel.get"(%arg15, %arg17, %arg15, %13, %13) <{chan_name = @L, operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (index, memref<4xi32>, index, index, index) -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "nested_segment"}> ({
  ^bb0(%arg6: memref<4xi32>, %arg7: memref<4xi32>, %arg8: memref<4xi32>):
    %7 = "air.segment"(%arg6, %arg7) <{operandSegmentSizes = array<i32: 0, 0, 2>}> ({
    ^bb0(%arg9: memref<4xi32>, %arg10: memref<4xi32>):
      %9 = "air.segment"(%arg9, %arg10) <{operandSegmentSizes = array<i32: 0, 0, 2>}> ({
      ^bb0(%arg11: memref<4xi32>, %arg12: memref<4xi32>):
        %10 = "air.dma_memcpy_nd"(%arg11, %arg12) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : (memref<4xi32>, memref<4xi32>) -> !air.async.token
      "air.segment_terminator"() : () -> ()
    }) : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    %8 = "air.dma_memcpy_nd"(%7, %arg8, %arg6) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "rank_talk"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 2 : index}> : () -> index
    %1 = "air.universe.alloc"(%0) : (index) -> !air.universe
    %2 = "air.rank"(%1, %0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<4xi32>, %arg5: memref<4xi32>):
      %3 = "arith.constant"() <{value = 1 : index}> : () -> index
      %4 = "arith.subi"(%3, %arg2) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %5 = "air.channel.put"(%4, %arg5, %arg2, %3, %3) <{chan_name = @R, operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 0>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (index, memref<4xi32>, index, index, index) -> !air.async.token
      %6 = "air.channel.get"(%arg2, %arg4, %arg2, %3, %3) <{chan_name = @R, operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>}> : (index, memref<4xi32>, index, index, index) -> !air.async.token
      "air.rank_terminator"() : () -> ()
    }) : (!air.universe, index, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
