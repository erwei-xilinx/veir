"builtin.module"() ({
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "device_bound_sync"}> ({
  ^bb0(%arg0: memref<1xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %3 = "memref.load"(%arg0, %0) : (memref<1xi32>, index) -> i32
    %4 = "arith.index_cast"(%3) : (i32) -> index
    "scf.for"(%0, %4, %1) ({
    ^bb0(%arg2: index):
      "memref.store"(%2, %arg1, %arg2) : (i32, memref<8xi32>, index) -> ()
      "scf.yield"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
