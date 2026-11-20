"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "pattern_on_view"}> ({
    %12 = "arith.constant"() <{value = 1 : index}> : () -> index
    %13 = "arith.constant"() <{value = 3 : index}> : () -> index
    %14 = "arith.constant"() <{value = 7 : index}> : () -> index
    %15 = "arith.constant"() <{value = 5 : i16}> : () -> i16
    %16 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi16>
    %17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi16>
    %18:2 = "air.execute"() ({
      %24 = "memref.subview"(%16) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 1, 0>, static_sizes = array<i64: 1, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi16>) -> memref<8xi16, strided<[1], offset: 8>>
      "air.execute_terminator"(%24) : (memref<8xi16, strided<[1], offset: 8>>) -> ()
    }) : () -> (!air.async.token, memref<8xi16, strided<[1], offset: 8>>)
    %19 = "arith.constant"() <{value = 2 : index}> : () -> index
    %20 = "arith.constant"() <{value = 4 : index}> : () -> index
    %21 = "air.dma_memcpy_nd"(%18#0, %17, %18#1, %19, %20, %12) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 1, 1, 1>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<4xi16>, memref<8xi16, strided<[1], offset: 8>>, index, index, index) -> !air.async.token
    %22 = "air.execute"() ({
      "memref.store"(%15, %16, %12, %13) : (i16, memref<4x8xi16>, index, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %23 = "air.execute"() ({
      "memref.store"(%15, %16, %12, %14) : (i16, memref<4x8xi16>, index, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%21, %22, %23) : (!air.async.token, !air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "fills_disjoint"}> ({
    %6 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi32>
    %8 = "air.execute"() ({
      %11 = "memref.subview"(%7) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 0, 0>, static_sizes = array<i64: 2, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi32>) -> memref<2x8xi32, strided<[8, 1]>>
      "linalg.fill"(%6, %11) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg6: i32, %arg7: i32):
        "linalg.yield"(%arg6) : (i32) -> ()
      }) : (i32, memref<2x8xi32, strided<[8, 1]>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %9 = "air.execute"() ({
      %10 = "memref.subview"(%7) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 2, 0>, static_sizes = array<i64: 2, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi32>) -> memref<2x8xi32, strided<[8, 1], offset: 16>>
      "linalg.fill"(%6, %10) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg4: i32, %arg5: i32):
        "linalg.yield"(%arg4) : (i32) -> ()
      }) : (i32, memref<2x8xi32, strided<[8, 1], offset: 16>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%8, %9) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "fills_overlap"}> ({
    %0 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %1 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi32>
    %2 = "air.execute"() ({
      %5 = "memref.subview"(%1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 0, 0>, static_sizes = array<i64: 2, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi32>) -> memref<2x8xi32, strided<[8, 1]>>
      "linalg.fill"(%0, %5) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg2: i32, %arg3: i32):
        "linalg.yield"(%arg2) : (i32) -> ()
      }) : (i32, memref<2x8xi32, strided<[8, 1]>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    %3 = "air.execute"() ({
      %4 = "memref.subview"(%1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 1, 0>, static_sizes = array<i64: 2, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi32>) -> memref<2x8xi32, strided<[8, 1], offset: 8>>
      "linalg.fill"(%0, %4) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg0: i32, %arg1: i32):
        "linalg.yield"(%arg0) : (i32) -> ()
      }) : (i32, memref<2x8xi32, strided<[8, 1], offset: 8>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%2, %3) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
