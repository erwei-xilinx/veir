"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "chain"}> ({
  ^bb0(%arg41: memref<16xi32>, %arg42: index):
    %53 = "arith.constant"() <{value = 0 : index}> : () -> index
    %54 = "arith.constant"() <{value = 1 : index}> : () -> index
    %55 = "air.wait_all"() : () -> !air.async.token
    %56 = "scf.for"(%53, %arg42, %54, %55) ({
    ^bb0(%arg43: index, %arg44: !air.async.token):
      %57 = "air.execute"(%arg44) ({
        %58 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%58, %arg41, %53) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%57) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "unordered"}> ({
  ^bb0(%arg37: memref<16xi32>, %arg38: index):
    %47 = "arith.constant"() <{value = 0 : index}> : () -> index
    %48 = "arith.constant"() <{value = 1 : index}> : () -> index
    %49 = "air.wait_all"() : () -> !air.async.token
    %50 = "scf.for"(%47, %arg38, %48, %49) ({
    ^bb0(%arg39: index, %arg40: !air.async.token):
      %51 = "air.execute"(%49) ({
        %52 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%52, %arg37, %47) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%arg40) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles"}> ({
  ^bb0(%arg34: memref<64xi32>, %arg35: index):
    %44 = "arith.constant"() <{value = 0 : index}> : () -> index
    %45 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%44, %arg35, %45) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg36: index):
      %46 = "arith.index_cast"(%arg36) : (index) -> i32
      "memref.store"(%46, %arg34, %arg36) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles_same"}> ({
  ^bb0(%arg31: memref<64xi32>, %arg32: index):
    %41 = "arith.constant"() <{value = 0 : index}> : () -> index
    %42 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%41, %arg32, %42) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg33: index):
      %43 = "arith.index_cast"(%arg33) : (index) -> i32
      "memref.store"(%43, %arg31, %41) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>) -> (), sym_name = "big"}> ({
  ^bb0(%arg28: memref<16xi32>):
    %34 = "arith.constant"() <{value = 0 : index}> : () -> index
    %35 = "arith.constant"() <{value = 1 : index}> : () -> index
    %36 = "arith.constant"() <{value = 100000 : index}> : () -> index
    %37 = "air.wait_all"() : () -> !air.async.token
    %38 = "scf.for"(%34, %36, %35, %37) ({
    ^bb0(%arg29: index, %arg30: !air.async.token):
      %39 = "air.execute"(%arg30) ({
        %40 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%40, %arg28, %34) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%39) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, memref<64xi32>, index) -> (), sym_name = "nest_wrap"}> ({
  ^bb0(%arg21: memref<64xi32>, %arg22: memref<64xi32>, %arg23: index):
    %27 = "arith.constant"() <{value = 0 : index}> : () -> index
    %28 = "arith.constant"() <{value = 1 : index}> : () -> index
    %29 = "arith.constant"() <{value = 8 : index}> : () -> index
    %30 = "air.wait_all"() : () -> !air.async.token
    %31 = "scf.for"(%27, %arg23, %28, %30) ({
    ^bb0(%arg24: index, %arg25: !air.async.token):
      %32 = "scf.for"(%27, %arg23, %28, %arg25) ({
      ^bb0(%arg26: index, %arg27: !air.async.token):
        %33 = "air.dma_memcpy_nd"(%arg27, %arg22, %27, %29, %28, %arg21, %27, %29, %28) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index, memref<64xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%33) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"(%32) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, memref<64xi32>, index) -> (), sym_name = "nest_unordered"}> ({
  ^bb0(%arg14: memref<64xi32>, %arg15: memref<64xi32>, %arg16: index):
    %20 = "arith.constant"() <{value = 0 : index}> : () -> index
    %21 = "arith.constant"() <{value = 1 : index}> : () -> index
    %22 = "arith.constant"() <{value = 8 : index}> : () -> index
    %23 = "air.wait_all"() : () -> !air.async.token
    %24 = "scf.for"(%20, %arg16, %21, %23) ({
    ^bb0(%arg17: index, %arg18: !air.async.token):
      %25 = "scf.for"(%20, %arg16, %21, %23) ({
      ^bb0(%arg19: index, %arg20: !air.async.token):
        %26 = "air.dma_memcpy_nd"(%arg20, %arg15, %20, %22, %21, %arg14, %20, %22, %21) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index, memref<64xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%26) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"(%25) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64x64xi32>, memref<64x64xi32>, index) -> (), sym_name = "reduce_then_copy"}> ({
  ^bb0(%arg7: memref<64x64xi32>, %arg8: memref<64x64xi32>, %arg9: index):
    %10 = "arith.constant"() <{value = 0 : index}> : () -> index
    %11 = "arith.constant"() <{value = 1 : index}> : () -> index
    %12 = "arith.constant"() <{value = 64 : index}> : () -> index
    %13 = "air.wait_all"() : () -> !air.async.token
    %14 = "scf.parallel"(%10, %10, %arg9, %arg9, %11, %11, %13) <{operandSegmentSizes = array<i32: 2, 2, 2, 1>}> ({
    ^bb0(%arg10: index, %arg11: index):
      %16:2 = "air.execute"() ({
        %19 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1x1xi32, 2>
        "air.execute_terminator"(%19) : (memref<1x1xi32, 2>) -> ()
      }) : () -> (!air.async.token, memref<1x1xi32, 2>)
      %17 = "air.dma_memcpy_nd"(%13, %16#0, %16#1, %arg7, %arg10, %arg11, %11, %11, %12, %11) <{operandSegmentSizes = array<i32: 2, 1, 0, 0, 0, 1, 2, 2, 2>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, !air.async.token, memref<1x1xi32, 2>, memref<64x64xi32>, index, index, index, index, index, index) -> !air.async.token
      "scf.reduce"(%17) ({
      ^bb0(%arg12: !air.async.token, %arg13: !air.async.token):
        %18 = "air.wait_all"(%arg12, %arg13) : (!air.async.token, !air.async.token) -> !air.async.token
        "scf.reduce.return"(%18) : (!air.async.token) -> ()
      }) : (!air.async.token) -> ()
    }) : (index, index, index, index, index, index, !air.async.token) -> !air.async.token
    %15 = "air.dma_memcpy_nd"(%14, %arg7, %10, %10, %12, %12, %12, %11, %arg8, %10, %10, %12, %12, %12, %11) <{operandSegmentSizes = array<i32: 1, 1, 2, 2, 2, 1, 2, 2, 2>, static_dst_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808, -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<64x64xi32>, index, index, index, index, index, index, memref<64x64xi32>, index, index, index, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64x64xi32>, memref<64x64xi32>, index) -> (), sym_name = "copy_beside_reduce"}> ({
  ^bb0(%arg0: memref<64x64xi32>, %arg1: memref<64x64xi32>, %arg2: index):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 64 : index}> : () -> index
    %3 = "air.wait_all"() : () -> !air.async.token
    %4 = "scf.parallel"(%0, %0, %arg2, %arg2, %1, %1, %3) <{operandSegmentSizes = array<i32: 2, 2, 2, 1>}> ({
    ^bb0(%arg3: index, %arg4: index):
      %6:2 = "air.execute"() ({
        %9 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1x1xi32, 2>
        "air.execute_terminator"(%9) : (memref<1x1xi32, 2>) -> ()
      }) : () -> (!air.async.token, memref<1x1xi32, 2>)
      %7 = "air.dma_memcpy_nd"(%3, %6#0, %6#1, %arg0, %arg3, %arg4, %1, %1, %2, %1) <{operandSegmentSizes = array<i32: 2, 1, 0, 0, 0, 1, 2, 2, 2>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, !air.async.token, memref<1x1xi32, 2>, memref<64x64xi32>, index, index, index, index, index, index) -> !air.async.token
      "scf.reduce"(%7) ({
      ^bb0(%arg5: !air.async.token, %arg6: !air.async.token):
        %8 = "air.wait_all"(%arg5, %arg6) : (!air.async.token, !air.async.token) -> !air.async.token
        "scf.reduce.return"(%8) : (!air.async.token) -> ()
      }) : (!air.async.token) -> ()
    }) : (index, index, index, index, index, index, !air.async.token) -> !air.async.token
    %5 = "air.dma_memcpy_nd"(%3, %arg0, %0, %0, %2, %2, %2, %1, %arg1, %0, %0, %2, %2, %2, %1) <{operandSegmentSizes = array<i32: 1, 1, 2, 2, 2, 1, 2, 2, 2>, static_dst_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808, -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> : (!air.async.token, memref<64x64xi32>, index, index, index, index, index, index, memref<64x64xi32>, index, index, index, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
