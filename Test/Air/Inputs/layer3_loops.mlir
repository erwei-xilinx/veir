// Generated from layer3_loops.air.mlir.src with air-opt (mlir-air 9b81b5de0) --mlir-print-op-generic --mlir-print-local-scope
"builtin.module"() ({
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "chain"}> ({
  ^bb0(%arg23: memref<8xi32>, %arg24: memref<8xi32>):
    %48 = "arith.constant"() <{value = 0 : index}> : () -> index
    %49 = "arith.constant"() <{value = 1 : index}> : () -> index
    %50 = "arith.constant"() <{value = 2 : index}> : () -> index
    %51 = "arith.constant"() <{value = 4 : index}> : () -> index
    %52:2 = "air.execute"() ({
      %57 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<2xi32, 1>
      "air.execute_terminator"(%57) : (memref<2xi32, 1>) -> ()
    }) : () -> (!air.async.token, memref<2xi32, 1>)
    %53 = "scf.for"(%48, %51, %49, %52#0) ({
    ^bb0(%arg25: index, %arg26: !air.async.token):
      %54 = "arith.muli"(%arg25, %50) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %55 = "air.dma_memcpy_nd"(%arg26, %52#1, %arg23, %54, %50, %49) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<2xi32, 1>, memref<8xi32>, index, index, index) -> !air.async.token
      %56 = "air.dma_memcpy_nd"(%55, %arg24, %54, %50, %49, %52#1) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>, index, index, index, memref<2xi32, 1>) -> !air.async.token
      "scf.yield"(%56) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "chain_broken"}> ({
  ^bb0(%arg19: memref<8xi32>, %arg20: memref<8xi32>):
    %38 = "arith.constant"() <{value = 0 : index}> : () -> index
    %39 = "arith.constant"() <{value = 1 : index}> : () -> index
    %40 = "arith.constant"() <{value = 2 : index}> : () -> index
    %41 = "arith.constant"() <{value = 4 : index}> : () -> index
    %42:2 = "air.execute"() ({
      %47 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<2xi32, 1>
      "air.execute_terminator"(%47) : (memref<2xi32, 1>) -> ()
    }) : () -> (!air.async.token, memref<2xi32, 1>)
    %43 = "scf.for"(%38, %41, %39, %42#0) ({
    ^bb0(%arg21: index, %arg22: !air.async.token):
      %44 = "arith.muli"(%arg21, %40) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %45 = "air.dma_memcpy_nd"(%42#0, %42#1, %arg19, %44, %40, %39) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<2xi32, 1>, memref<8xi32>, index, index, index) -> !air.async.token
      %46 = "air.dma_memcpy_nd"(%45, %arg22, %arg20, %44, %40, %39, %42#1) <{operandSegmentSizes = array<i32: 2, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, !air.async.token, memref<8xi32>, index, index, index, memref<2xi32, 1>) -> !air.async.token
      "scf.yield"(%46) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "ping_pong"}> ({
  ^bb0(%arg14: memref<8xi32>, %arg15: memref<8xi32>):
    %23 = "arith.constant"() <{value = 0 : index}> : () -> index
    %24 = "arith.constant"() <{value = 1 : index}> : () -> index
    %25 = "arith.constant"() <{value = 2 : index}> : () -> index
    %26 = "arith.constant"() <{value = 4 : index}> : () -> index
    %27:2 = "air.execute"() ({
      %37 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<2xi32, 1>
      "air.execute_terminator"(%37) : (memref<2xi32, 1>) -> ()
    }) : () -> (!air.async.token, memref<2xi32, 1>)
    %28:2 = "air.execute"() ({
      %36 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<2xi32, 1>
      "air.execute_terminator"(%36) : (memref<2xi32, 1>) -> ()
    }) : () -> (!air.async.token, memref<2xi32, 1>)
    %29:2 = "scf.for"(%23, %26, %25, %27#0, %28#0) ({
    ^bb0(%arg16: index, %arg17: !air.async.token, %arg18: !air.async.token):
      %30 = "arith.muli"(%arg16, %25) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %31 = "arith.addi"(%30, %25) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %32 = "air.dma_memcpy_nd"(%arg17, %27#1, %arg14, %30, %25, %24) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<2xi32, 1>, memref<8xi32>, index, index, index) -> !air.async.token
      %33 = "air.dma_memcpy_nd"(%32, %arg15, %30, %25, %24, %27#1) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>, index, index, index, memref<2xi32, 1>) -> !air.async.token
      %34 = "air.dma_memcpy_nd"(%arg18, %28#1, %arg14, %31, %25, %24) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<2xi32, 1>, memref<8xi32>, index, index, index) -> !air.async.token
      %35 = "air.dma_memcpy_nd"(%34, %arg15, %31, %25, %24, %28#1) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 0, 0, 0>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>, index, index, index, memref<2xi32, 1>) -> !air.async.token
      "scf.yield"(%33, %35) : (!air.async.token, !air.async.token) -> ()
    }) : (index, index, index, !air.async.token, !air.async.token) -> (!air.async.token, !air.async.token)
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>, memref<8xi32>) -> (), sym_name = "parallel_tiles"}> ({
  ^bb0(%arg8: memref<8xi32>, %arg9: memref<8xi32>, %arg10: memref<8xi32>):
    %14 = "arith.constant"() <{value = 0 : index}> : () -> index
    %15 = "arith.constant"() <{value = 1 : index}> : () -> index
    %16 = "arith.constant"() <{value = 2 : index}> : () -> index
    %17 = "arith.constant"() <{value = 8 : index}> : () -> index
    %18 = "air.wait_all"() : () -> !air.async.token
    %19 = "scf.parallel"(%14, %17, %16, %18) <{operandSegmentSizes = array<i32: 1, 1, 1, 1>}> ({
    ^bb0(%arg11: index):
      %21 = "air.dma_memcpy_nd"(%18, %arg9, %arg11, %16, %15, %arg8, %arg11, %16, %15) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      "scf.reduce"(%21) ({
      ^bb0(%arg12: !air.async.token, %arg13: !air.async.token):
        %22 = "air.wait_all"(%arg12, %arg13) : (!air.async.token, !air.async.token) -> !air.async.token
        "scf.reduce.return"(%22) : (!air.async.token) -> ()
      }) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    %20 = "air.dma_memcpy_nd"(%19, %arg10, %arg9) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "parallel_overlap"}> ({
  ^bb0(%arg3: memref<8xi32>, %arg4: memref<8xi32>):
    %5 = "arith.constant"() <{value = 0 : index}> : () -> index
    %6 = "arith.constant"() <{value = 1 : index}> : () -> index
    %7 = "arith.constant"() <{value = 2 : index}> : () -> index
    %8 = "arith.constant"() <{value = 3 : index}> : () -> index
    %9 = "arith.constant"() <{value = 6 : index}> : () -> index
    %10 = "air.wait_all"() : () -> !air.async.token
    %11 = "scf.parallel"(%5, %9, %7, %10) <{operandSegmentSizes = array<i32: 1, 1, 1, 1>}> ({
    ^bb0(%arg5: index):
      %12 = "air.dma_memcpy_nd"(%10, %arg4, %arg5, %8, %6, %arg3, %arg5, %8, %6) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      "scf.reduce"(%12) ({
      ^bb0(%arg6: !air.async.token, %arg7: !air.async.token):
        %13 = "air.wait_all"(%arg6, %arg7) : (!air.async.token, !air.async.token) -> !air.async.token
        "scf.reduce.return"(%13) : (!air.async.token) -> ()
      }) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (index) -> (), sym_name = "dynamic_trips"}> ({
  ^bb0(%arg0: index):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "air.wait_all"() : () -> !air.async.token
    %3 = "scf.for"(%0, %arg0, %1, %2) ({
    ^bb0(%arg1: index, %arg2: !air.async.token):
      %4 = "air.wait_all"(%arg2) : (!air.async.token) -> !air.async.token
      "scf.yield"(%4) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
