"builtin.module"() ({
  "func.func"() <{function_type = (memref<1xi32>, memref<8xi32>) -> (), sym_name = "device_bound_sync"}> ({
  ^bb0(%arg0: memref<1xi32>, %arg1: memref<8xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %3:2 = "air.execute"() ({
      %10 = "memref.load"(%arg0, %0) : (memref<1xi32>, index) -> i32
      "air.execute_terminator"(%10) : (i32) -> ()
    }) {id = 1 : i32} : () -> (!air.async.token, i32)
    %4 = "arith.index_cast"(%3#1) : (i32) -> index
    %5 = "air.wait_all"() {id = 1 : i32} : () -> !air.async.token
    %6 = "scf.for"(%0, %4, %1, %5) ({
    ^bb0(%arg2: index, %arg3: !air.async.token):
      %7 = "arith.constant"() <{value = 7 : i32}> : () -> i32
      %8 = "air.execute"(%arg3) ({
        "memref.store"(%7, %arg1, %arg2) : (i32, memref<8xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) {id = 2 : i32} : (!air.async.token) -> !air.async.token
      %9 = "air.wait_all"(%8) {id = 2 : i32} : (!air.async.token) -> !air.async.token
      "scf.yield"(%9) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
