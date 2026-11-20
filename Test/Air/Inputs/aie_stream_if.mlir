"builtin.module"() ({
  "aie.device"() <{device = 3 : i32, sym_name = "segment_0"}> ({
    %27 = "aie.tile"() <{col = 2 : i32, row = 3 : i32}> : () -> index
    %28 = "aie.tile"() <{col = 2 : i32, row = 4 : i32}> : () -> index
    %29 = "aie.lock"(%27) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %30 = "aie.lock"(%27) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %31 = "aie.lock"(%28) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %32 = "aie.lock"(%28) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %33 = "aie.buffer"(%28) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<576xi8, 2>
    %34 = "aie.buffer"(%27) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<576xi8, 2>
    %35 = "aie.mem"(%28) ({
      %53 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %54 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%31, %53) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%33) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%32, %53) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %36 = "aie.core"(%28) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %43 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %44 = "arith.constant"() <{value = 8 : index}> : () -> index
      %45 = "arith.constant"() <{value = 1 : index}> : () -> index
      %46 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%32, %43) <{action = 2 : i32}> : (index, i32) -> ()
      %47:3 = "aievec.fifo_start"(%33, %46) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
      %48 = "func.call"() <{callee = @cond}> : () -> i1
      %49:3 = "scf.if"(%48) ({
        %52:5 = "aievec.fifo_ld_pop_bfp16"(%47#0, %47#1, %47#2) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%52#3, %52#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%52#0, %52#1, %52#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }, {
        "scf.yield"(%47#0, %47#1, %47#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) : (i1) -> (!llvm.ptr, vector<32xi32>, i32)
      "func.call"() <{callee = @other}> : () -> ()
      %50:3 = "scf.for"(%46, %44, %45, %49#0, %49#1, %49#2) ({
      ^bb0(%arg12: index, %arg13: !llvm.ptr, %arg14: vector<32xi32>, %arg15: i32):
        %51:5 = "aievec.fifo_ld_pop_bfp16"(%arg13, %arg14, %arg15) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
        "func.call"(%51#3, %51#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
        "scf.yield"(%51#0, %51#1, %51#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
      "aie.use_lock"(%31, %43) <{action = 1 : i32}> : (index, i32) -> ()
      "func.call"() <{callee = @other}> : () -> ()
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 1>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    %37 = "aie.mem"(%27) ({
      %41 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %42 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%30, %41) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%34) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 576 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<576xi8, 2>) -> ()
      "aie.use_lock"(%29, %41) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %38 = "aie.core"(%27) <{link_with = "w.o", stack_size = 2048 : i32}> ({
      %40 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // pred: ^bb0
      "cf.br"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%29, %40) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%30, %40) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.end"() : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "herd_0", air.herd_size = array<i64: 1, 2>} : (index) -> index
    "air.channel"() <{channel_type = "npu_dma_stream", size = [1, 1], sym_name = "channel_0"}> : () -> ()
    %39 = "aie.logical_tile"() <{tile_type = 1 : i32}> : () -> index
    "func.func"() <{function_type = () -> i1, sym_name = "cond", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "func.func"() <{function_type = (vector<64xi8>, vector<8xi8>) -> (), sym_name = "use", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "func.func"() <{function_type = () -> (), sym_name = "other", sym_visibility = "private"}> ({
    }) {link_with = "w.o", llvm.emit_c_interface} : () -> ()
    "aie.flow"(%27, %28) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
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
  "func.func"() <{function_type = () -> (), sym_name = "stream_through_if"}> ({
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
            %23:2 = "air.execute"() ({
              %26 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%26) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %24 = "air.channel.put"(%23#0, %23#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0, 0>, static_src_offsets = array<i64>, static_src_sizes = array<i64>, static_src_strides = array<i64>}> {id = 1 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %25 = "air.execute"(%24) ({
              "memref.dealloc"(%23#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%25) : (!air.async.token) -> ()
          }, {
            %11:2 = "air.execute"() ({
              %22 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<576xi8, 2>
              "air.execute_terminator"(%22) : (memref<576xi8, 2>) -> ()
            }) : () -> (!air.async.token, memref<576xi8, 2>)
            %12 = "air.channel.get"(%11#0, %11#1) <{chan_name = @channel_0, operandSegmentSizes = array<i32: 1, 0, 1, 0, 0, 0>, static_dst_offsets = array<i64>, static_dst_sizes = array<i64>, static_dst_strides = array<i64>}> {id = 2 : i32} : (!air.async.token, memref<576xi8, 2>) -> !air.async.token
            %13 = "air.execute"(%12) ({
              %16:3 = "aievec.fifo_start"(%11#1, %8) : (memref<576xi8, 2>, index) -> (!llvm.ptr, vector<32xi32>, i32)
              %17 = "func.call"() <{callee = @cond}> : () -> i1
              %18:3 = "scf.if"(%17) ({
                %21:5 = "aievec.fifo_ld_pop_bfp16"(%16#0, %16#1, %16#2) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%21#3, %21#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%21#0, %21#1, %21#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }, {
                "scf.yield"(%16#0, %16#1, %16#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (i1) -> (!llvm.ptr, vector<32xi32>, i32)
              "func.call"() <{callee = @other}> : () -> ()
              %19:3 = "scf.for"(%8, %7, %6, %18#0, %18#1, %18#2) ({
              ^bb0(%arg8: index, %arg9: !llvm.ptr, %arg10: vector<32xi32>, %arg11: i32):
                %20:5 = "aievec.fifo_ld_pop_bfp16"(%arg9, %arg10, %arg11) : (!llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32, vector<64xi8>, vector<8xi8>)
                "func.call"(%20#3, %20#4) <{callee = @use}> : (vector<64xi8>, vector<8xi8>) -> ()
                "scf.yield"(%20#0, %20#1, %20#2) : (!llvm.ptr, vector<32xi32>, i32) -> ()
              }) : (index, index, index, !llvm.ptr, vector<32xi32>, i32) -> (!llvm.ptr, vector<32xi32>, i32)
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %14 = "air.execute"(%13) ({
              "func.call"() <{callee = @other}> : () -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            %15 = "air.execute"(%14) ({
              "memref.dealloc"(%11#1) : (memref<576xi8, 2>) -> ()
              "air.execute_terminator"() : () -> ()
            }) : (!air.async.token) -> !air.async.token
            "scf.yield"(%15) : (!air.async.token) -> ()
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
