"builtin.module"() ({
  "aie.device"() <{device = 3 : i32, sym_name = "segment_0"}> ({
    %36 = "aie.tile"() <{col = 2 : i32, row = 3 : i32}> : () -> index
    %37 = "aie.tile"() <{col = 2 : i32, row = 4 : i32}> : () -> index
    %38 = "aie.lock"(%36) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %39 = "aie.lock"(%36) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %40 = "aie.lock"(%37) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %41 = "aie.lock"(%37) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %42 = "aie.buffer"(%37) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<576xi8, 2>
    %43 = "aie.buffer"(%36) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<576xi8, 2>
    %44 = "aie.mem"(%37) ({
      %67 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %68 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%40, %67) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%42) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%41, %67) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %45 = "aie.core"(%37) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %52 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %53 = "arith.constant"() <{value = 1 : i64}> : () -> i64
      %54 = "arith.constant"() <{value = 8 : index}> : () -> index
      %55 = "arith.constant"() <{value = 1 : index}> : () -> index
      %56 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%41, %52) <{action = 2 : i32}> : (index, i32) -> ()
      %57 = "llvm.alloca"(%53) <{elem_type = !llvm.ptr}> : (i64) -> !llvm.ptr
      %58:3 = "aievec.fifo_start"(%42, %56) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
      "llvm.store"(%58#0, %57) <{ordering = 0 : i64}> : (!llvm.ptr, !llvm.ptr) -> ()
      "func.call"() <{callee = @other}> : () -> ()
      %59 = "llvm.load"(%57) <{ordering = 0 : i64}> : (!llvm.ptr) -> !llvm.ptr
      %60:3 = "scf.for"(%56, %54, %55, %59, %58#1, %58#2) ({
      ^bb0(%arg20: index, %arg21: !llvm.ptr, %arg22: vector<32xi32>, %arg23: i32):
        %66:5 = "aievec.fifo_ld_pop_bfp16"(%arg21, %arg22, %arg23) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%66#3, %66#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%66#0, %66#1, %66#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
      "func.call"() <{callee = @other}> : () -> ()
      "aie.use_lock"(%40, %52) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%41, %52) <{action = 2 : i32}> : (index, i32) -> ()
      %61 = "llvm.alloca"(%53) <{elem_type = !llvm.ptr}> : (i64) -> !llvm.ptr
      %62:3 = "aievec.fifo_start"(%42, %56) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
      "llvm.store"(%62#0, %61) <{ordering = 0 : i64}> : (!llvm.ptr, !llvm.ptr) -> ()
      "func.call"() <{callee = @other}> : () -> ()
      %63 = "llvm.load"(%61) <{ordering = 0 : i64}> : (!llvm.ptr) -> !llvm.ptr
      %64:3 = "scf.for"(%56, %54, %55, %63, %62#1, %62#2) ({
      ^bb0(%arg16: index, %arg17: !llvm.ptr, %arg18: vector<32xi32>, %arg19: i32):
        %65:5 = "aievec.fifo_ld_pop_bfp16"(%arg17, %arg18, %arg19) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%65#3, %65#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%65#0, %65#1, %65#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
      "func.call"() <{callee = @other}> : () -> ()
      "aie.use_lock"(%40, %52) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 1>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    %46 = "aie.mem"(%36) ({
      %50 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %51 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%39, %50) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%43) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%38, %50) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %47 = "aie.core"(%36) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %49 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%38, %49) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%39, %49) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%38, %49) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%39, %49) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "channel_0"}> : () -> ()
    %48 = "aie.logical_tile"() <{tile_type = 1 : i32}> : () -> index
    "func.func"() <{function_type = () -> (), sym_name = "other", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "func.func"() <{function_type = (vector<64xi8>, vector<8xi8>) -> (), sym_name = "use", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "aie.flow"(%36, %37) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
  "airrt.module_metadata"() ({
    "airrt.segment_metadata"() <{sym_name = "segment_0"}> ({
      "airrt.herd_metadata"() <{sym_name = "herd_0"}> {dma_allocations = [], loc_x = 2 : i64, loc_y = 3 : i64, size_x = 1 : i64, size_y = 2 : i64} : () -> ()
      "airrt.segment_metadata_terminator"() : () -> ()
    }) {dma_allocations = []} : () -> ()
    "airrt.module_metadata_terminator"() : () -> ()
  }) : () -> ()
  "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "channel_0"}> : () -> ()
  "func.func"() <{function_type = (vector<64xi8>, vector<8xi8>) -> (), sym_name = "use", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "other", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = () -> i1, sym_name = "cond", sym_visibility = "private"}> ({
  }) : () -> ()
  "func.func"() <{function_type = () -> (), sym_name = "ring_stream_pointer_stored"}> ({
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "air.launch"(%0, %0) <{operandSegmentSizes = array<i32: 0, 2, 0>}> ({
    ^bb0(%arg0: index, %arg1: index, %arg2: index, %arg3: index):
      %2 = "air.segment"() <{operandSegmentSizes = array<i32: 0, 0, 0>}> ({
        %3 = "arith.constant"() <{value = 2 : index}> : () -> index
        %4 = "arith.constant"() <{value = 1 : index}> : () -> index
        %5 = "air.herd"(%4, %3) <{link_with = "w.o", operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "herd_0"}> ({
        ^bb0(%arg4: index, %arg5: index, %arg6: index, %arg7: index):
          %6 = "arith.constant"() <{value = 1 : i64}> : () -> i64
          %7 = "arith.constant"() <{value = 1 : index}> : () -> index
          %8 = "arith.constant"() <{value = 8 : index}> : () -> index
          %9 = "arith.constant"() <{value = 0 : index}> : () -> index
          %10 = "arith.cmpi"(%arg5, %9) <{predicate = 0 : i64}> : (index, index) -> i1
          %11 = "scf.if"(%10) ({
            %31:2 = "air.execute"() ({
              %35 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%35) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %32 = "air.channel.put"(%31#0, %31#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 1 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %33 = "air.channel.put"(%32, %31#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 2 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %34 = "air.execute"(%33) ({
              "memref.dealloc"(%31#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%34) : (!air.async.token) -> ()
          }, {
            %12:2 = "air.execute"() ({
              %30 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%30) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %13 = "air.channel.get"(%12#0, %12#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 3 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %14 = "air.execute"(%13) ({
              %25 = "llvm.alloca"(%6) <{elem_type = !llvm.ptr}> : (i64) -> !llvm.ptr
              %26:3 = "aievec.fifo_start"(%12#1, %9) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
              "llvm.store"(%26#0, %25) <{ordering = 0 : i64}> : (!llvm.ptr, !llvm.ptr) -> ()
              "func.call"() <{callee = @other}> : () -> ()
              %27 = "llvm.load"(%25) <{ordering = 0 : i64}> : (!llvm.ptr) -> !llvm.ptr
              %28:3 = "scf.for"(%9, %8, %7, %27, %26#1, %26#2) ({
              ^bb0(%arg12: index, %arg13: !llvm.ptr, %arg14: vector<32xi32>, %arg15: i32):
                %29:5 = "aievec.fifo_ld_pop_bfp16"(%arg13, %arg14, %arg15) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%29#3, %29#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%29#0, %29#1, %29#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %15 = "air.execute"(%14) ({
              "func.call"() <{callee = @other}> : () -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %16 = "air.channel.get"(%15, %12#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 4 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %17 = "air.execute"(%16) ({
              %20 = "llvm.alloca"(%6) <{elem_type = !llvm.ptr}> : (i64) -> !llvm.ptr
              %21:3 = "aievec.fifo_start"(%12#1, %9) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
              "llvm.store"(%21#0, %20) <{ordering = 0 : i64}> : (!llvm.ptr, !llvm.ptr) -> ()
              "func.call"() <{callee = @other}> : () -> ()
              %22 = "llvm.load"(%20) <{ordering = 0 : i64}> : (!llvm.ptr) -> !llvm.ptr
              %23:3 = "scf.for"(%9, %8, %7, %22, %21#1, %21#2) ({
              ^bb0(%arg8: index, %arg9: !llvm.ptr, %arg10: vector<32xi32>, %arg11: i32):
                %24:5 = "aievec.fifo_ld_pop_bfp16"(%arg9, %arg10, %arg11) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%24#3, %24#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%24#0, %24#1, %24#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %18 = "air.execute"(%17) ({
              "func.call"() <{callee = @other}> : () -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %19 = "air.execute"(%18) ({
              "memref.dealloc"(%12#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%19) : (!air.async.token) -> ()
          }) : (i1) -> !air.async.token
          "air.herd_terminator"() : () -> ()
        }) {x_loc = 2 : i32, y_loc = 3 : i32} : (index, index) -> !air.async.token
        "air.segment_terminator"() : () -> ()
      }) : () -> !air.async.token
      "air.launch_terminator"() : () -> ()
    }) : (index, index) -> !air.async.token
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
