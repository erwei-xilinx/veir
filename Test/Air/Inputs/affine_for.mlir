"builtin.module"() ({
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "bounds"}> ({
  ^bb0(%arg8: memref<8xi32>, %arg9: memref<8xi32>):
    %5 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%5, %arg8, %arg9) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg10: index, %arg11: index, %arg12: memref<8xi32>, %arg13: memref<8xi32>):
      %6 = "arith.constant"() <{value = 3 : index}> : () -> index
      "affine.for"(%6, %6) <{lowerBoundMap = affine_map<()[s0] -> (0, s0 - 5)>, operandSegmentSizes = array<i32: 1, 1, 0>, step = 2 : index, upperBoundMap = affine_map<()[s0] -> (7, s0 + 10)>}> ({
      ^bb0(%arg14: index):
        %7 = "affine.load"(%arg12, %arg14) <{map = affine_map<(d0) -> (d0 + 1)>}> : (memref<8xi32>, index) -> i32
        "affine.store"(%7, %arg13, %arg14) <{map = affine_map<(d0) -> (d0)>}> : (i32, memref<8xi32>, index) -> ()
        "affine.yield"() : () -> ()
      }) : (index, index) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<8xi32>, memref<8xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "carried"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    "air.launch"(%0, %arg0, %arg1) <{operandSegmentSizes = array<i32: 0, 1, 2>}> ({
    ^bb0(%arg2: index, %arg3: index, %arg4: memref<4xi32>, %arg5: memref<4xi32>):
      %1 = "air.wait_all"() : () -> !air.async.token
      %2 = "affine.for"(%1) <{lowerBoundMap = affine_map<() -> (0)>, operandSegmentSizes = array<i32: 0, 0, 1>, step = 1 : index, upperBoundMap = affine_map<() -> (4)>}> ({
      ^bb0(%arg6: index, %arg7: !air.async.token):
        %3 = "air.execute"(%arg7) ({
          %4 = "affine.load"(%arg4, %arg6) <{map = affine_map<(d0) -> (d0)>}> : (memref<4xi32>, index) -> i32
          "affine.store"(%4, %arg5, %arg6) <{map = affine_map<(d0) -> (-d0 + 3)>}> : (i32, memref<4xi32>, index) -> ()
          "air.execute_terminator"() : () -> ()
        }) : (!air.async.token) -> !air.async.token
        "affine.yield"(%3) : (!air.async.token) -> ()
      }) : (!air.async.token) -> !air.async.token
      "air.wait_all"(%2) : (!air.async.token) -> ()
      "air.launch_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
