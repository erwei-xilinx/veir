"builtin.module"() ({
  "air.channel"() <{channel_type = "gpu_symmetric_heap", size = [], sym_name = "Sig"}> : () -> ()
  "func.func"() <{function_type = (memref<4xi32>) -> (), sym_name = "kernel", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "signalled_read"}> ({
  ^bb0(%arg18: memref<4xi32>, %arg19: memref<4xi32>):
    %14 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.rank"(%14, %arg18, %arg19) <{operandSegmentSizes = array<i32: 0, 0, 1, 2>}> ({
    ^bb0(%arg20: index, %arg21: index, %arg22: memref<4xi32>, %arg23: memref<4xi32>):
      %15 = "arith.constant"() <{value = 0 : index}> : () -> index
      %16 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
      %17 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32>
      %18 = "arith.cmpi"(%arg20, %15) <{predicate = 0 : i64}> : (index, index) -> i1
      "scf.if"(%18) ({
        "air.dma_memcpy_nd"(%16, %arg23) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "air.channel.put"(%17) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1xi32>) -> ()
        "scf.yield"() : () -> ()
      }, {
        "air.channel.get"(%17) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1xi32>) -> ()
        "air.dma_memcpy_nd"(%arg22, %16) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, src_rank = 0 : i64, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "scf.yield"() : () -> ()
      }) : (i1) -> ()
      "air.rank_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "unsignalled_read"}> ({
  ^bb0(%arg12: memref<4xi32>, %arg13: memref<4xi32>):
    %10 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.rank"(%10, %arg12, %arg13) <{operandSegmentSizes = array<i32: 0, 0, 1, 2>}> ({
    ^bb0(%arg14: index, %arg15: index, %arg16: memref<4xi32>, %arg17: memref<4xi32>):
      %11 = "arith.constant"() <{value = 0 : index}> : () -> index
      %12 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
      %13 = "arith.cmpi"(%arg14, %11) <{predicate = 0 : i64}> : (index, index) -> i1
      "scf.if"(%13) ({
        "air.dma_memcpy_nd"(%12, %arg17) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "scf.yield"() : () -> ()
      }, {
        "air.dma_memcpy_nd"(%arg16, %12) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, src_rank = 0 : i64, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "scf.yield"() : () -> ()
      }) : (i1) -> ()
      "air.rank_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>, memref<2xindex>) -> (), sym_name = "translate_read"}> ({
  ^bb0(%arg4: memref<4xi32>, %arg5: memref<4xi32>, %arg6: memref<2xindex>):
    %4 = "arith.constant"() <{value = 2 : index}> : () -> index
    "air.rank"(%4, %arg4, %arg5, %arg6) <{operandSegmentSizes = array<i32: 0, 0, 1, 3>}> ({
    ^bb0(%arg7: index, %arg8: index, %arg9: memref<4xi32>, %arg10: memref<4xi32>, %arg11: memref<2xindex>):
      %5 = "arith.constant"() <{value = 0 : index}> : () -> index
      %6 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> {air.symmetric} : () -> memref<4xi32>
      %7 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<1xi32>
      %8 = "arith.cmpi"(%arg7, %5) <{predicate = 0 : i64}> : (index, index) -> i1
      "scf.if"(%8) ({
        "air.dma_memcpy_nd"(%6, %arg10) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "air.channel.put"(%7) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<1xi32>) -> ()
        "scf.yield"() : () -> ()
      }, {
        %9 = "air.translate"(%6, %arg7, %5, %arg11) : (memref<4xi32>, index, index, memref<2xindex>) -> memref<4xi32>
        "air.channel.get"(%7) <{chan_name = @Sig, operandSegmentSizes = array<i32: 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> : (memref<1xi32>) -> ()
        "air.dma_memcpy_nd"(%arg9, %9) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> ()
        "scf.yield"() : () -> ()
      }) : (i1) -> ()
      "air.rank_terminator"() : () -> ()
    }) : (index, memref<4xi32>, memref<4xi32>, memref<2xindex>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "custom_ordered"}> ({
  ^bb0(%arg2: memref<4xi32>, %arg3: memref<4xi32>):
    %2 = "air.custom"(%arg2) <{operandSegmentSizes = array<i32: 0, 1>}> {sym_name = "kernel"} : (memref<4xi32>) -> !air.async.token
    %3 = "air.dma_memcpy_nd"(%2, %arg3, %arg2) <{operandSegmentSizes = array<i32: 1, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (!air.async.token, memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "custom_unordered"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<4xi32>):
    %0 = "air.custom"(%arg0) <{operandSegmentSizes = array<i32: 0, 1>}> {sym_name = "kernel"} : (memref<4xi32>) -> !air.async.token
    %1 = "air.dma_memcpy_nd"(%arg1, %arg0) <{operandSegmentSizes = array<i32: 0, 1, 0, 0, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> : (memref<4xi32>, memref<4xi32>) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
