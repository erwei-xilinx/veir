"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "chain"}> ({
  ^bb0(%arg13: memref<16xi32>, %arg14: index):
    %19 = "arith.constant"() <{value = 0 : index}> : () -> index
    %20 = "arith.constant"() <{value = 1 : index}> : () -> index
    %21 = "air.wait_all"() : () -> !air.async.token
    %22 = "scf.for"(%19, %arg14, %20, %21) ({
    ^bb0(%arg15: index, %arg16: !air.async.token):
      %23 = "air.execute"(%arg16) ({
        %24 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%24, %arg13, %19) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%23) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "unordered"}> ({
  ^bb0(%arg9: memref<16xi32>, %arg10: index):
    %13 = "arith.constant"() <{value = 0 : index}> : () -> index
    %14 = "arith.constant"() <{value = 1 : index}> : () -> index
    %15 = "air.wait_all"() : () -> !air.async.token
    %16 = "scf.for"(%13, %arg10, %14, %15) ({
    ^bb0(%arg11: index, %arg12: !air.async.token):
      %17 = "air.execute"(%15) ({
        %18 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%18, %arg9, %13) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%arg12) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles"}> ({
  ^bb0(%arg6: memref<64xi32>, %arg7: index):
    %10 = "arith.constant"() <{value = 0 : index}> : () -> index
    %11 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%10, %arg7, %11) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg8: index):
      %12 = "arith.index_cast"(%arg8) : (index) -> i32
      "memref.store"(%12, %arg6, %arg8) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles_same"}> ({
  ^bb0(%arg3: memref<64xi32>, %arg4: index):
    %7 = "arith.constant"() <{value = 0 : index}> : () -> index
    %8 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%7, %arg4, %8) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg5: index):
      %9 = "arith.index_cast"(%arg5) : (index) -> i32
      "memref.store"(%9, %arg3, %7) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>) -> (), sym_name = "big"}> ({
  ^bb0(%arg0: memref<16xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 100000 : index}> : () -> index
    %3 = "air.wait_all"() : () -> !air.async.token
    %4 = "scf.for"(%0, %2, %1, %3) ({
    ^bb0(%arg1: index, %arg2: !air.async.token):
      %5 = "air.execute"(%arg2) ({
        %6 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%6, %arg0, %0) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%5) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
