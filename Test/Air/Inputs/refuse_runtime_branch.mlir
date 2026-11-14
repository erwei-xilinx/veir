"builtin.module"() ({
  "func.func"() <{function_type = (memref<1xi32>, memref<4xi32>, memref<4xi32>) -> (), sym_name = "runtime_branch"}> ({
  ^bb0(%arg0: memref<1xi32>, %arg1: memref<4xi32>, %arg2: memref<4xi32>):
    %0:2 = "air.execute"() ({
      %4 = "arith.constant"() <{value = 0 : index}> : () -> index
      %5 = "memref.load"(%arg0, %4) : (memref<1xi32>, index) -> i32
      "air.execute_terminator"(%5) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    %1 = "arith.constant"() <{value = 0 : i32}> : () -> i32
    %2 = "arith.cmpi"(%0#1, %1) <{predicate = 1 : i64}> : (i32, i32) -> i1
    "scf.if"(%2) ({
      %3 = "air.dma_memcpy_nd"(%0#0, %arg1, %arg2) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
      "scf.yield"() : () -> ()
    }, {
    }) : (i1) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
