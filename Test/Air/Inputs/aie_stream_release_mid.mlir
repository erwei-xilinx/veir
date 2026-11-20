"builtin.module"() ({
  "aie.device"() <{device = 3 : i32, sym_name = "segment_0"}> ({
    %30 = "aie.tile"() <{col = 2 : i32, row = 3 : i32}> : () -> index
    %31 = "aie.tile"() <{col = 2 : i32, row = 4 : i32}> : () -> index
    %32 = "aie.lock"(%30) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %33 = "aie.lock"(%30) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %34 = "aie.lock"(%31) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %35 = "aie.lock"(%31) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %36 = "aie.buffer"(%31) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<576xi8, 2>
    %37 = "aie.buffer"(%30) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<576xi8, 2>
    %38 = "aie.mem"(%31) ({
      %56 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %57 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%34, %56) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%36) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%35, %56) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %39 = "aie.core"(%31) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %46 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %47 = "arith.constant"() <{value = 8 : index}> : () -> index
      %48 = "arith.constant"() <{value = 1 : index}> : () -> index
      %49 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%35, %46) <{action = 2 : i32}> : (index, i32) -> ()
      %50:3 = "aievec.fifo_start"(%36, %49) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
      "aie.use_lock"(%34, %46) <{action = 1 : i32}> : (index, i32) -> ()
      %51:3 = "scf.for"(%49, %47, %48, %50#0, %50#1, %50#2) ({
      ^bb0(%arg20: index, %arg21: !llvm.ptr, %arg22: vector<32xi32>, %arg23: i32):
        %55:5 = "aievec.fifo_ld_pop_bfp16"(%arg21, %arg22, %arg23) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%55#3, %55#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%55#0, %55#1, %55#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
      "func.call"() <{callee = @other}> : () -> ()
      "aie.use_lock"(%35, %46) <{action = 2 : i32}> : (index, i32) -> ()
      %52:3 = "aievec.fifo_start"(%36, %49) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
      "aie.use_lock"(%34, %46) <{action = 1 : i32}> : (index, i32) -> ()
      %53:3 = "scf.for"(%49, %47, %48, %52#0, %52#1, %52#2) ({
      ^bb0(%arg16: index, %arg17: !llvm.ptr, %arg18: vector<32xi32>, %arg19: i32):
        %54:5 = "aievec.fifo_ld_pop_bfp16"(%arg17, %arg18, %arg19) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%54#3, %54#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%54#0, %54#1, %54#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 1>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    %40 = "aie.mem"(%30) ({
      %44 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %45 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%33, %44) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%37) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%32, %44) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %41 = "aie.core"(%30) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %43 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%32, %43) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%33, %43) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%32, %43) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%33, %43) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "channel_0"}> : () -> ()
    %42 = "aie.logical_tile"() <{tile_type = 1 : i32}> : () -> index
    "func.func"() <{function_type = (vector<64xi8>, vector<8xi8>) -> (), sym_name = "use", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "func.func"() <{function_type = () -> (), sym_name = "other", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "aie.flow"(%30, %31) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
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
  "func.func"() <{function_type = () -> (), sym_name = "ring_release_after_stream"}> ({
    %0 = "arith.constant"() <{value = 1 : index}> : () -> index
    %1 = "air.launch"(%0, %0) <{operandSegmentSizes = array<i32: 0, 2, 0>}> ({
    ^bb0(%arg0: index, %arg1: index, %arg2: index, %arg3: index):
      %2 = "air.segment"() <{operandSegmentSizes = array<i32: 0, 0, 0>}> ({
        %3 = "arith.constant"() <{value = 2 : index}> : () -> index
        %4 = "arith.constant"() <{value = 1 : index}> : () -> index
        %5 = "air.herd"(%4, %3) <{link_with = "w.o", operandSegmentSizes = array<i32: 0, 2, 0>, sym_name = "herd_0"}> ({
        ^bb0(%arg4: index, %arg5: index, %arg6: index, %arg7: index):
          %6 = "arith.constant"() <{value = 1 : index}> : () -> index
          %7 = "arith.constant"() <{value = 8 : index}> : () -> index
          %8 = "arith.constant"() <{value = 0 : index}> : () -> index
          %9 = "arith.cmpi"(%arg5, %8) <{predicate = 0 : i64}> : (index, index) -> i1
          %10 = "scf.if"(%9) ({
            %25:2 = "air.execute"() ({
              %29 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%29) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %26 = "air.channel.put"(%25#0, %25#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 1 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %27 = "air.channel.put"(%26, %25#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 2 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %28 = "air.execute"(%27) ({
              "memref.dealloc"(%25#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%28) : (!air.async.token) -> ()
          }, {
            %11:2 = "air.execute"() ({
              %24 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%24) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %12 = "air.channel.get"(%11#0, %11#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 3 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %13 = "air.execute"(%12) ({
              %21:3 = "aievec.fifo_start"(%11#1, %8) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
              %22:3 = "scf.for"(%8, %7, %6, %21#0, %21#1, %21#2) ({
              ^bb0(%arg12: index, %arg13: !llvm.ptr, %arg14: vector<32xi32>, %arg15: i32):
                %23:5 = "aievec.fifo_ld_pop_bfp16"(%arg13, %arg14, %arg15) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%23#3, %23#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%23#0, %23#1, %23#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %14 = "air.execute"(%13) ({
              "func.call"() <{callee = @other}> : () -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %15 = "air.channel.get"(%14, %11#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 4 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %16 = "air.execute"(%15) ({
              %18:3 = "aievec.fifo_start"(%11#1, %8) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
              %19:3 = "scf.for"(%8, %7, %6, %18#0, %18#1, %18#2) ({
              ^bb0(%arg8: index, %arg9: !llvm.ptr, %arg10: vector<32xi32>, %arg11: i32):
                %20:5 = "aievec.fifo_ld_pop_bfp16"(%arg9, %arg10, %arg11) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%20#3, %20#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%20#0, %20#1, %20#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %17 = "air.execute"(%16) ({
              "memref.dealloc"(%11#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%17) : (!air.async.token) -> ()
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
