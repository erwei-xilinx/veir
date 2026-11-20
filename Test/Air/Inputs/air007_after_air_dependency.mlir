// air-dependency's output for the reproducer of AIR-007 (air-dependency misses overlapping accesses) (mlir-air 9b81b5de0)
"builtin.module"() ({
  "func.func"() <{function_type = (memref<4x8xi32>, memref<1x8xi32>) -> (), sym_name = "f"}> ({
  ^bb0(%arg0: memref<4x8xi32>, %arg1: memref<1x8xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 2 : index}> : () -> index
    %3 = "arith.constant"() <{value = 8 : index}> : () -> index
    %4:2 = "air.execute"() ({
      %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4x8xi32, 1>
      "air.execute_terminator"(%7) : (memref<4x8xi32, 1>) -> ()
    }) {id = 1 : i32} : () -> (!air.async.token, memref<4x8xi32, 1>)
    %5 = "air.dma_memcpy_nd"(%4#0, %4#1, %1, %0, %2, %3, %3, %1, %arg0, %1, %0, %2, %3, %3, %1) <{operandSegmentSizes = array<i32: 1, 1, 2, 2, 2, 1, 2, 2, 2>, static_dst_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808, -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> {id = 1 : i32} : (!air.async.token, memref<4x8xi32, 1>, index, index, index, index, index, index, memref<4x8xi32>, index, index, index, index, index, index) -> !air.async.token
    %6 = "air.dma_memcpy_nd"(%4#0, %arg1, %4#1, %2, %0, %1, %3, %3, %1) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 2, 2, 2>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64: -9223372036854775808, -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808, -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808, -9223372036854775808>}> {id = 2 : i32} : (!air.async.token, memref<1x8xi32>, memref<4x8xi32, 1>, index, index, index, index, index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
