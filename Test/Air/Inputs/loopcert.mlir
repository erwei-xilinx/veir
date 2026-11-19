"builtin.module"() ({
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "chain"}> ({
  ^bb0(%arg27: memref<16xi32>, %arg28: index):
    %33 = "arith.constant"() <{value = 0 : index}> : () -> index
    %34 = "arith.constant"() <{value = 1 : index}> : () -> index
    %35 = "air.wait_all"() : () -> !air.async.token
    %36 = "scf.for"(%33, %arg28, %34, %35) ({
    ^bb0(%arg29: index, %arg30: !air.async.token):
      %37 = "air.execute"(%arg30) ({
        %38 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%38, %arg27, %33) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%37) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>, index) -> (), sym_name = "unordered"}> ({
  ^bb0(%arg23: memref<16xi32>, %arg24: index):
    %27 = "arith.constant"() <{value = 0 : index}> : () -> index
    %28 = "arith.constant"() <{value = 1 : index}> : () -> index
    %29 = "air.wait_all"() : () -> !air.async.token
    %30 = "scf.for"(%27, %arg24, %28, %29) ({
    ^bb0(%arg25: index, %arg26: !air.async.token):
      %31 = "air.execute"(%29) ({
        %32 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%32, %arg23, %27) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%arg26) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles"}> ({
  ^bb0(%arg20: memref<64xi32>, %arg21: index):
    %24 = "arith.constant"() <{value = 0 : index}> : () -> index
    %25 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%24, %arg21, %25) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg22: index):
      %26 = "arith.index_cast"(%arg22) : (index) -> i32
      "memref.store"(%26, %arg20, %arg22) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, index) -> (), sym_name = "tiles_same"}> ({
  ^bb0(%arg17: memref<64xi32>, %arg18: index):
    %21 = "arith.constant"() <{value = 0 : index}> : () -> index
    %22 = "arith.constant"() <{value = 1 : index}> : () -> index
    "scf.parallel"(%21, %arg18, %22) <{operandSegmentSizes = array<i32: 1, 1, 1, 0>}> ({
    ^bb0(%arg19: index):
      %23 = "arith.index_cast"(%arg19) : (index) -> i32
      "memref.store"(%23, %arg17, %21) : (i32, memref<64xi32>, index) -> ()
      "scf.reduce"() : () -> ()
    }) : (index, index, index) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<16xi32>) -> (), sym_name = "big"}> ({
  ^bb0(%arg14: memref<16xi32>):
    %14 = "arith.constant"() <{value = 0 : index}> : () -> index
    %15 = "arith.constant"() <{value = 1 : index}> : () -> index
    %16 = "arith.constant"() <{value = 100000 : index}> : () -> index
    %17 = "air.wait_all"() : () -> !air.async.token
    %18 = "scf.for"(%14, %16, %15, %17) ({
    ^bb0(%arg15: index, %arg16: !air.async.token):
      %19 = "air.execute"(%arg16) ({
        %20 = "arith.constant"() <{value = 7 : i32}> : () -> i32
        "memref.store"(%20, %arg14, %14) : (i32, memref<16xi32>, index) -> ()
        "air.execute_terminator"() : () -> ()
      }) : (!air.async.token) -> !air.async.token
      "scf.yield"(%19) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, memref<64xi32>, index) -> (), sym_name = "nest_wrap"}> ({
  ^bb0(%arg7: memref<64xi32>, %arg8: memref<64xi32>, %arg9: index):
    %7 = "arith.constant"() <{value = 0 : index}> : () -> index
    %8 = "arith.constant"() <{value = 1 : index}> : () -> index
    %9 = "arith.constant"() <{value = 8 : index}> : () -> index
    %10 = "air.wait_all"() : () -> !air.async.token
    %11 = "scf.for"(%7, %arg9, %8, %10) ({
    ^bb0(%arg10: index, %arg11: !air.async.token):
      %12 = "scf.for"(%7, %arg9, %8, %arg11) ({
      ^bb0(%arg12: index, %arg13: !air.async.token):
        %13 = "air.dma_memcpy_nd"(%arg13, %arg8, %7, %9, %8, %arg7, %7, %9, %8) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index, memref<64xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%13) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"(%12) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<64xi32>, memref<64xi32>, index) -> (), sym_name = "nest_unordered"}> ({
  ^bb0(%arg0: memref<64xi32>, %arg1: memref<64xi32>, %arg2: index):
    %0 = "arith.constant"() <{value = 0 : index}> : () -> index
    %1 = "arith.constant"() <{value = 1 : index}> : () -> index
    %2 = "arith.constant"() <{value = 8 : index}> : () -> index
    %3 = "air.wait_all"() : () -> !air.async.token
    %4 = "scf.for"(%0, %arg2, %1, %3) ({
    ^bb0(%arg3: index, %arg4: !air.async.token):
      %5 = "scf.for"(%0, %arg2, %1, %3) ({
      ^bb0(%arg5: index, %arg6: !air.async.token):
        %6 = "air.dma_memcpy_nd"(%arg6, %arg1, %0, %2, %1, %arg0, %0, %2, %1) <{operandSegmentSizes = array<i32: 1, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (!air.async.token, memref<64xi32>, index, index, index, memref<64xi32>, index, index, index) -> !air.async.token
        "scf.yield"(%6) : (!air.async.token) -> ()
      }) : (index, index, index, !air.async.token) -> !air.async.token
      "scf.yield"(%5) : (!air.async.token) -> ()
    }) : (index, index, index, !air.async.token) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
