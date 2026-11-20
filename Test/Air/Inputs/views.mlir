"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "sub_of_sub"}> ({
    %9 = "arith.constant"() <{value = 2 : index}> : () -> index
    %10 = "arith.constant"() <{value = 4 : index}> : () -> index
    %11 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi32>
    %13 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    %14:2 = "air.execute"() ({
      %17 = "memref.subview"(%12) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 1, 0>, static_sizes = array<i64: 2, 8>, static_strides = array<i64: 1, 1>}> : (memref<4x8xi32>) -> memref<2x8xi32, strided<[8, 1], offset: 8>>
      %18 = "memref.subview"(%17) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 1, 4>, static_sizes = array<i64: 1, 4>, static_strides = array<i64: 1, 1>}> : (memref<2x8xi32, strided<[8, 1], offset: 8>>) -> memref<1x4xi32, strided<[8, 1], offset: 20>>
      "air.execute_terminator"(%18) : (memref<1x4xi32, strided<[8, 1], offset: 20>>) -> ()
    }) : () -> (!air.async.token, memref<1x4xi32, strided<[8, 1], offset: 20>>)
    %15 = "air.dma_memcpy_nd"(%14#0, %13, %14#1) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<1x4xi32, strided<[8, 1], offset: 20>>) -> !air.async.token
    %16 = "air.execute"() ({
      "memref.store"(%11, %12, %9, %10) : (i32, memref<4x8xi32>, index, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%15, %16) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "transpose_view"}> ({
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "arith.constant"() <{value = 3 : index}> : () -> index
    %2 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %3 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x4xi32>
    %4 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %5:2 = "air.execute"() ({
      %8 = "memref.transpose"(%3) <{permutation = affine_map<(d0, d1) -> (d1, d0)>}> : (memref<4x4xi32>) -> memref<4x4xi32, strided<[1, 4]>>
      "air.execute_terminator"(%8) : (memref<4x4xi32, strided<[1, 4]>>) -> ()
    }) : () -> (!air.async.token, memref<4x4xi32, strided<[1, 4]>>)
    %6 = "air.dma_memcpy_nd"(%5#0, %4, %5#1) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<16xi32>, memref<4x4xi32, strided<[1, 4]>>) -> !air.async.token
    %7 = "air.execute"() ({
      "memref.store"(%2, %3, %1, %0) : (i32, memref<4x4xi32>, index, index) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%6, %7) : (!air.async.token, !air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
