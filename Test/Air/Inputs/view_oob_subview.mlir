"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "subview_past_row"}> ({
    %0 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %1 = "arith.constant"() <{value = 12 : index}> : () -> index
    %2 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<8x16xi32>
    %3 = "air.execute"() ({
      %4 = "memref.subview"(%2, %1) <{operandSegmentSizes = array<i32: 1, 1, 0, 0>, static_offsets = array<i64: 0, -9223372036854775808>, static_sizes = array<i64: 1, 8>, static_strides = array<i64: 1, 1>}> : (memref<8x16xi32>, index) -> memref<1x8xi32, strided<[16, 1], offset: ?>>
      "linalg.fill"(%0, %4) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg0: i32, %arg1: i32):
        "linalg.yield"(%arg0) : (i32) -> ()
      }) : (i32, memref<1x8xi32, strided<[16, 1], offset: ?>>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "air.wait_all"(%3) : (!air.async.token) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
