"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>, memref<1xi32>) -> (), sym_name = "forall_disjoint"}> ({
  ^bb0(%arg9: memref<16xi32>, %arg10: memref<1xi32>):
    %12 = "arith.constant"() <{value = 1 : index}> : () -> index
    %13 = "arith.constant"() <{value = 0 : index}> : () -> index
    %14 = "arith.constant"() <{value = 8 : index}> : () -> index
    "scf.forall"(%12) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, staticLowerBound = array<i64: 0, -9223372036854775808>, staticStep = array<i64: 1, 4>, staticUpperBound = array<i64: 2, 8>}> ({
    ^bb0(%arg11: index, %arg12: index):
      %18 = "arith.muli"(%arg11, %14) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %19 = "arith.addi"(%18, %arg12) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %20 = "arith.constant"() <{value = 100 : index}> : () -> index
      %21 = "arith.addi"(%19, %20) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %22 = "arith.index_cast"(%21) : (index) -> i32
      "memref.store"(%22, %arg9, %19) : (i32, memref<16xi32>, index) -> ()
      "scf.forall.in_parallel"() ({
      ^bb0:
      }) : () -> ()
    }) : (index) -> ()
    %15 = "memref.load"(%arg9, %13) : (memref<16xi32>, index) -> i32
    %16 = "memref.load"(%arg9, %12) : (memref<16xi32>, index) -> i32
    %17 = "arith.addi"(%15, %16) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
    "memref.store"(%17, %arg10, %13) : (i32, memref<1xi32>, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4x8xi32>) -> (), sym_name = "affine_groups"}> ({
  ^bb0(%arg6: memref<4x8xi32>):
    %8 = "arith.constant"() <{value = 3 : index}> : () -> index
    "affine.parallel"(%8, %8) <{lowerBoundsGroups = dense<[1, 2]> : tensor<2xi32>, lowerBoundsMap = affine_map<(d0) -> (0, 0, d0 - 2)>, reductions = [], steps = [1, 2], upperBoundsGroups = dense<[1, 2]> : tensor<2xi32>, upperBoundsMap = affine_map<(d0) -> (2, 8, d0 + 2)>}> ({
    ^bb0(%arg7: index, %arg8: index):
      %9 = "arith.constant"() <{value = 100 : index}> : () -> index
      %10 = "arith.addi"(%arg8, %9) <{overflowFlags = #arith.overflow<none>}> : (index, index) -> index
      %11 = "arith.index_cast"(%10) : (index) -> i32
      "affine.store"(%11, %arg6, %arg7, %arg8) <{map = affine_map<(d0, d1) -> (d0, d1)>}> : (i32, memref<4x8xi32>, index, index) -> ()
      "affine.yield"() : () -> ()
    }) : (index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "forall_same"}> ({
  ^bb0(%arg4: memref<4xi32>):
    %6 = "arith.constant"() <{value = 0 : index}> : () -> index
    "scf.forall"() <{operandSegmentSizes = array<i32: 0, 0, 0, 0>, staticLowerBound = array<i64: 0>, staticStep = array<i64: 1>, staticUpperBound = array<i64: 2>}> ({
    ^bb0(%arg5: index):
      %7 = "arith.index_cast"(%arg5) : (index) -> i32
      "memref.store"(%7, %arg4, %6) : (i32, memref<4xi32>, index) -> ()
      "scf.forall.in_parallel"() ({
      ^bb0:
      }) : () -> ()
    }) : () -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "affine_same"}> ({
  ^bb0(%arg2: memref<4xi32>):
    %4 = "arith.constant"() <{value = 0 : index}> : () -> index
    "affine.parallel"() <{lowerBoundsGroups = dense<1> : tensor<1xi32>, lowerBoundsMap = affine_map<() -> (0)>, reductions = [], steps = [1], upperBoundsGroups = dense<1> : tensor<1xi32>, upperBoundsMap = affine_map<() -> (2)>}> ({
    ^bb0(%arg3: index):
      %5 = "arith.index_cast"(%arg3) : (index) -> i32
      "memref.store"(%5, %arg2, %4) : (i32, memref<4xi32>, index) -> ()
      "affine.yield"() : () -> ()
    }) : () -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "parallel_same"}> ({
  ^bb0(%arg0: memref<4xi32>):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 2 : index}> : () -> index
    "scf.parallel"(%0, %2, %1) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg1: index):
      %3 = "arith.index_cast"(%arg1) : (index) -> i32
      "memref.store"(%3, %arg0, %0) : (i32, memref<4xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
