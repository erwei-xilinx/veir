"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "cast_past_end"}> ({
    %0 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %1 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32>
    %2 = "air.execute"() ({
      %3 = "memref.reinterpret_cast"(%1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 8>, static_sizes = array<i64: 4, 4>, static_strides = array<i64: 4, 1>}> : (memref<16xi32>) -> memref<4x4xi32, strided<[4, 1], offset: 8>>
      "linalg.fill"(%0, %3) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg0: i32, %arg1: i32):
        "linalg.yield"(%arg0) : (i32) -> ()
      }) : (i32, memref<4x4xi32, strided<[4, 1], offset: 8>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%2) : (!air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
