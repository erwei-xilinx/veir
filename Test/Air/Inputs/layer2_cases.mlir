// Generated from layer2_cases.air.mlir.src with air-opt (mlir-air 9b81b5de0) --mlir-print-op-generic --mlir-print-local-scope
"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>, memref<1xi32>) -> (), sym_name = "stride0_dst"}> ({
  ^bb0(%arg17: memref<4xi32>, %arg18: memref<1xi32>):
    %47 = "arith.constant"() <{value = 0 : index}> : () -> index
    %48 = "arith.constant"() <{value = 1 : index}> : () -> index
    %49 = "arith.constant"() <{value = 4 : index}> : () -> index
    %50 = "air.dma_memcpy_nd"(%arg18, %47, %49, %47, %arg17, %47, %49, %48) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<1xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<2xi32>, memref<4xi32>) -> (), sym_name = "padding"}> ({
  ^bb0(%arg15: memref<2xi32>, %arg16: memref<4xi32>):
    %42 = "arith.constant"() <{value = 0 : index}> : () -> index
    %43 = "arith.constant"() <{value = 1 : index}> : () -> index
    %44 = "arith.constant"() <{value = 2 : index}> : () -> index
    %45 = "arith.constant"() <{value = 4 : index}> : () -> index
    %46 = "air.dma_memcpy_nd"(%arg16, %42, %45, %43, %arg15, %42, %44, %43) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, pad_after = array<i32: 1>, pad_before = array<i32: 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<2xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "overlap_down"}> ({
  ^bb0(%arg14: memref<4xi32>):
    %38 = "arith.constant"() <{value = 0 : index}> : () -> index
    %39 = "arith.constant"() <{value = 1 : index}> : () -> index
    %40 = "arith.constant"() <{value = 3 : index}> : () -> index
    %41 = "air.dma_memcpy_nd"(%arg14, %38, %40, %39, %arg14, %39, %40, %39) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "overlap_up"}> ({
  ^bb0(%arg13: memref<4xi32>):
    %34 = "arith.constant"() <{value = 0 : index}> : () -> index
    %35 = "arith.constant"() <{value = 1 : index}> : () -> index
    %36 = "arith.constant"() <{value = 3 : index}> : () -> index
    %37 = "air.dma_memcpy_nd"(%arg13, %35, %36, %35, %arg13, %34, %36, %35) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "count_mismatch"}> ({
  ^bb0(%arg11: memref<4xi32>, %arg12: memref<8xi32>):
    %29 = "arith.constant"() <{value = 0 : index}> : () -> index
    %30 = "arith.constant"() <{value = 1 : index}> : () -> index
    %31 = "arith.constant"() <{value = 4 : index}> : () -> index
    %32 = "arith.constant"() <{value = 8 : index}> : () -> index
    %33 = "air.dma_memcpy_nd"(%arg12, %29, %32, %30, %arg11, %29, %31, %30) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "out_of_bounds"}> ({
  ^bb0(%arg9: memref<4xi32>, %arg10: memref<4xi32>):
    %24 = "arith.constant"() <{value = 0 : index}> : () -> index
    %25 = "arith.constant"() <{value = 1 : index}> : () -> index
    %26 = "arith.constant"() <{value = 2 : index}> : () -> index
    %27 = "arith.constant"() <{value = 4 : index}> : () -> index
    %28 = "air.dma_memcpy_nd"(%arg10, %24, %27, %25, %arg9, %26, %27, %25) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>, index) -> (), sym_name = "dynamic"}> ({
  ^bb0(%arg6: memref<8xi32>, %arg7: memref<8xi32>, %arg8: index):
    %19 = "arith.constant"() <{value = 0 : index}> : () -> index
    %20 = "arith.constant"() <{value = 1 : index}> : () -> index
    %21 = "arith.constant"() <{value = 4 : index}> : () -> index
    %22 = "air.dma_memcpy_nd"(%arg7, %19, %21, %20, %arg6, %19, %21, %20) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
    %23 = "air.dma_memcpy_nd"(%arg7, %arg8, %21, %20, %arg6, %21, %21, %20) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "linalg"}> ({
  ^bb0(%arg2: memref<4xi32>, %arg3: memref<4xi32>):
    %13 = "arith.constant"() <{value = 0 : index}> : () -> index
    %14 = "arith.constant"() <{value = 1 : index}> : () -> index
    %15 = "arith.constant"() <{value = 4 : index}> : () -> index
    %16 = "air.execute"() ({
      %18 = "arith.constant"() <{value = 0 : i32}> : () -> i32
      "linalg.fill"(%18, %arg2) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg4: i32, %arg5: i32):
        "linalg.yield"(%arg4) : (i32) -> ()
      }) : (i32, memref<4xi32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %17 = "air.dma_memcpy_nd"(%arg3, %13, %15, %14, %arg2, %13, %15, %14) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<4xi32>, index, index, index, memref<4xi32>, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "dealloc_race"}> ({
  ^bb0(%arg1: memref<4xi32>):
    %6 = "arith.constant"() <{value = 0 : index}> : () -> index
    %7 = "arith.constant"() <{value = 1 : index}> : () -> index
    %8 = "arith.constant"() <{value = 4 : index}> : () -> index
    %9:2 = "air.execute"() ({
      %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32, 1>
      "air.execute_terminator"(%12) : (memref<4xi32, 1>) -> ()
    }) : () -> (!air.async.token, memref<4xi32, 1>)
    %10 = "air.dma_memcpy_nd"(%9#0, %arg1, %6, %8, %7, %9#1, %6, %8, %7) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<4xi32>, index, index, index, memref<4xi32, 1>, index, index, index) -> !air.async.token
    %11 = "air.execute"(%9#0) ({
      "memref.dealloc"(%9#1) : (memref<4xi32, 1>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : (!air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<2xi32>) -> (), sym_name = "load_store"}> ({
  ^bb0(%arg0: memref<2xi32>):
    %0 = "air.execute"() ({
      %4 = "arith.constant"() <{value = 1 : index}> : () -> index
      %5 = "arith.constant"() <{value = 7 : i32}> : () -> i32
      "memref.store"(%5, %arg0, %4) : (i32, memref<2xi32>, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %1:2 = "air.execute"(%0) ({
      %2 = "arith.constant"() <{value = 1 : index}> : () -> index
      %3 = "memref.load"(%arg0, %2) : (memref<2xi32>, index) -> i32
      "air.execute_terminator"(%3) : (i32) -> ()
    }) : (!air.async.token) -> (!air.async.token, i32)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
