"builtin.module"() ({
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "if_on_tile"}> ({
  ^bb0(%arg35: memref<8xi32>, %arg36: memref<8xi32>):
    %29 = "arith.constant"() <{value = 2 : index}> : () -> index
    %30 = "arith.constant"() <{value = 1 : index}> : () -> index
    %31 = "air.herd"(%29, %30, %arg35, %arg36) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg37: index, %arg38: index, %arg39: index, %arg40: index, %arg41: memref<8xi32>, %arg42: memref<8xi32>):
      %32 = "arith.constant"() <{value = 0 : index}> : () -> index
      %33 = "arith.constant"() <{value = 1 : index}> : () -> index
      %34 = "arith.constant"() <{value = 4 : index}> : () -> index
      %35 = "arith.cmpi"(%arg37, %32) <{predicate = 0 : i64}> : (index, index) -> i1
      "scf.if"(%35) ({
        %37 = "air.dma_memcpy_nd"(%arg41, %32, %34, %33, %arg42, %32, %34, %33) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
        "scf.yield"() : () -> ()
      }, {
        %36 = "air.dma_memcpy_nd"(%arg41, %34, %34, %33, %arg42, %34, %34, %33) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
        "scf.yield"() : () -> ()
      }) : (i1) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "apply_offset"}> ({
  ^bb0(%arg27: memref<8xi32>, %arg28: memref<8xi32>):
    %22 = "arith.constant"() <{value = 2 : index}> : () -> index
    %23 = "arith.constant"() <{value = 1 : index}> : () -> index
    %24 = "air.herd"(%22, %23, %arg27, %arg28) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg29: index, %arg30: index, %arg31: index, %arg32: index, %arg33: memref<8xi32>, %arg34: memref<8xi32>):
      %25 = "arith.constant"() <{value = 1 : index}> : () -> index
      %26 = "arith.constant"() <{value = 4 : index}> : () -> index
      %27 = "affine.apply"(%arg29) <{map = affine_map<(d0) -> (d0 * 4)>}> : (index) -> index
      %28 = "air.dma_memcpy_nd"(%arg33, %27, %26, %25, %arg34, %27, %26, %25) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "affine_if"}> ({
  ^bb0(%arg19: memref<8xi32>, %arg20: memref<8xi32>):
    %18 = "arith.constant"() <{value = 2 : index}> : () -> index
    %19 = "arith.constant"() <{value = 1 : index}> : () -> index
    %20 = "air.herd"(%18, %19, %arg19, %arg20) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg21: index, %arg22: index, %arg23: index, %arg24: index, %arg25: memref<8xi32>, %arg26: memref<8xi32>):
      "affine.if"(%arg21) <{condition = affine_set<(d0) : (-d0 >= 0)>}> ({
        %21 = "air.dma_memcpy_nd"(%arg25, %arg26) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<8xi32>, memref<8xi32>) -> !air.async.token
        "affine.yield"() : () -> ()
      }, {
      }) : (index) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "index_switch"}> ({
  ^bb0(%arg11: memref<8xi32>, %arg12: memref<8xi32>):
    %10 = "arith.constant"() <{value = 2 : index}> : () -> index
    %11 = "arith.constant"() <{value = 1 : index}> : () -> index
    %12 = "air.herd"(%10, %11, %arg11, %arg12) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg13: index, %arg14: index, %arg15: index, %arg16: index, %arg17: memref<8xi32>, %arg18: memref<8xi32>):
      %13 = "arith.constant"() <{value = 0 : index}> : () -> index
      %14 = "arith.constant"() <{value = 1 : index}> : () -> index
      %15 = "arith.constant"() <{value = 4 : index}> : () -> index
      "scf.index_switch"(%arg13) <{cases = array<i64: 0>}> ({
        %17 = "air.dma_memcpy_nd"(%arg17, %15, %15, %14, %arg18, %15, %15, %14) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
        "scf.yield"() : () -> ()
      }, {
        %16 = "air.dma_memcpy_nd"(%arg17, %13, %15, %14, %arg18, %13, %15, %14) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
        "scf.yield"() : () -> ()
      }) : (index) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<8xi32>, memref<8xi32>) -> (), sym_name = "if_same_branch"}> ({
  ^bb0(%arg3: memref<8xi32>, %arg4: memref<8xi32>):
    %2 = "arith.constant"() <{value = 2 : index}> : () -> index
    %3 = "arith.constant"() <{value = 1 : index}> : () -> index
    %4 = "air.herd"(%2, %3, %arg3, %arg4) <{operandSegmentSizes = array<i32: 0, 2, 2>}> ({
    ^bb0(%arg5: index, %arg6: index, %arg7: index, %arg8: index, %arg9: memref<8xi32>, %arg10: memref<8xi32>):
      %5 = "arith.constant"() <{value = 0 : index}> : () -> index
      %6 = "arith.constant"() <{value = 1 : index}> : () -> index
      %7 = "arith.constant"() <{value = 4 : index}> : () -> index
      %8 = "arith.cmpi"(%arg5, %7) <{predicate = 6 : i64}> : (index, index) -> i1
      "scf.if"(%8) ({
        %9 = "air.dma_memcpy_nd"(%arg9, %5, %7, %6, %arg10, %5, %7, %6) <{operandSegmentSizes = array<i32: 0, 1, 1, 1, 1, 1, 1, 1, 1>, static_dst_offsets = array<i64: -9223372036854775808>, static_dst_sizes = array<i64: -9223372036854775808>, static_dst_strides = array<i64: -9223372036854775808>, static_src_offsets = array<i64: -9223372036854775808>, static_src_sizes = array<i64: -9223372036854775808>, static_src_strides = array<i64: -9223372036854775808>}> : (memref<8xi32>, index, index, index, memref<8xi32>, index, index, index) -> !air.async.token
        "scf.yield"() : () -> ()
      }, {
      }) : (i1) -> ()
      "air.herd_terminator"() : () -> ()
    }) : (index, index, memref<8xi32>, memref<8xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xf32>) -> (), sym_name = "float_fill"}> ({
  ^bb0(%arg0: memref<4xf32>):
    %0 = "air.execute"() ({
      %1 = "arith.constant"() <{value = 0.000000e+00 : f32}> : () -> f32
      "linalg.fill"(%1, %arg0) <{operandSegmentSizes = array<i32: 1, 1>}> ({
      ^bb0(%arg1: f32, %arg2: f32):
        "linalg.yield"(%arg1) : (f32) -> ()
      }) : (f32, memref<4xf32>) -> ()
      "air.execute_terminator"() : () -> ()
    }) : () -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
