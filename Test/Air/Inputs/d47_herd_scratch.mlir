"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>) -> (), sym_name = "herd_scratch"}> ({
  ^bb0(%arg0: memref<16xi32>):
    %0 = "arith.constant"() <{value = 2 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<16xi32, 2>
    "air.herd"(%0, %1, %2) <{operandSegmentSizes = array<i32: 0, 2, 1>}> ({
    ^bb0(%arg1: index, %arg2: index, %arg3: index, %arg4: index, %arg5: memref<16xi32, 2>):
      %3 = "arith.constant"() <{value = 0 : i32}> : () -> i32
      "linalg.fill"(%3, %arg5) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg6: i32, %arg7: i32):
        "linalg.yield"(%arg6) : (i32) -> ()
      }) : (i32, memref<16xi32, 2>) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<16xi32, 2>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
