// Hand-edited from an aircc packet design: both packet flows (ids 0, 1) into shim (0, 0) S2MM 0, one 32-element receive task. T8: the two packets arrive in either order.
"builtin.module"() ({
  "aie.device"() <{device = 8 : i32, sym_name = "seg"}> ({
    %0 = "aie.tile"() <{col = 1 : i32, row = 0 : i32}> : () -> index
    %1 = "aie.tile"() <{col = 0 : i32, row = 0 : i32}> : () -> index
    %2 = "aie.tile"() <{col = 0 : i32, row = 2 : i32}> : () -> index
    %3 = "aie.tile"() <{col = 1 : i32, row = 2 : i32}> : () -> index
    %4 = "aie.lock"(%2) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %5 = "aie.lock"(%2) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %6 = "aie.lock"(%2) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %7 = "aie.lock"(%2) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %8 = "aie.lock"(%3) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %9 = "aie.lock"(%3) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %10 = "aie.lock"(%3) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %11 = "aie.lock"(%3) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %12 = "aie.buffer"(%3) <{aligned = true, sym_name = "buf3"}> : (index) -> memref<16xi32, 2>
    %13 = "aie.buffer"(%3) <{aligned = true, sym_name = "buf2"}> : (index) -> memref<16xi32, 2>
    %14 = "aie.buffer"(%2) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<16xi32, 2>
    %15 = "aie.buffer"(%2) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<16xi32, 2>
    %16 = "aie.external_buffer"() <{sym_name = "__air_external_buffer"}> : () -> memref<32xi32>
    %17 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_1"}> : () -> memref<32xi32>
    %18 = "aie.mem"(%3) ({
      %39 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %40 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%11, %39) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%13) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_type = 0, pkt_id = 1>, static_len = 16 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<16xi32, 2>) -> ()
      "aie.use_lock"(%10, %39) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %41 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%8, %39) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%12) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 16 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<16xi32, 2>) -> ()
      "aie.use_lock"(%9, %39) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %19 = "aie.core"(%3) <{stack_size = 2048 : i32}> ({
      %34 = "arith.constant"() <{value = 1 : index}> : () -> index
      %35 = "arith.constant"() <{value = 16 : index}> : () -> index
      %36 = "arith.constant"() <{value = 0 : index}> : () -> index
      %37 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%10, %37) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%9, %37) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%36, %35, %34) ({
      ^bb0(%arg3: index):
        %38 = "memref.load"(%12, %arg3) : (memref<16xi32, 2>, index) -> i32
        "memref.store"(%38, %13, %arg3) : (i32, memref<16xi32, 2>, index) -> ()
        "scf.yield"() : () -> ()
      }) : (index, index, index) -> ()
      "aie.use_lock"(%8, %37) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%11, %37) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 1, 0>, air.herd_name = "h", air.herd_size = array<i64: 2, 1>} : (index) -> index
    %20 = "aie.mem"(%2) ({
      %31 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %32 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%7, %31) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%15) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_type = 0, pkt_id = 0>, static_len = 16 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<16xi32, 2>) -> ()
      "aie.use_lock"(%6, %31) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %33 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%4, %31) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%14) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 16 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<16xi32, 2>) -> ()
      "aie.use_lock"(%5, %31) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %21 = "aie.core"(%2) <{stack_size = 2048 : i32}> ({
      %26 = "arith.constant"() <{value = 1 : index}> : () -> index
      %27 = "arith.constant"() <{value = 16 : index}> : () -> index
      %28 = "arith.constant"() <{value = 0 : index}> : () -> index
      %29 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%6, %29) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%5, %29) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%28, %27, %26) ({
      ^bb0(%arg2: index):
        %30 = "memref.load"(%14, %arg2) : (memref<16xi32, 2>, index) -> i32
        "memref.store"(%30, %15, %arg2) : (i32, memref<16xi32, 2>, index) -> ()
        "scf.yield"() : () -> ()
      }) : (index, index, index) -> ()
      "aie.use_lock"(%4, %29) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%7, %29) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "h", air.herd_size = array<i64: 2, 1>} : (index) -> index
    "aie.packet_flow"() <{ID = 0 : i8}> ({
      "aie.packet_source"(%2) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.packet_dest"(%1) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.end"() : () -> ()
    }) : () -> ()
    "aie.packet_flow"() <{ID = 1 : i8}> ({
      "aie.packet_source"(%3) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.packet_dest"(%1) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.end"() : () -> ()
    }) : () -> ()
    "aie.flow"(%1, %2) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%0, %3) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.shim_dma_allocation"(%1) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_Out_0"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_Out_1"}> : (index) -> ()
    "aie.shim_dma_allocation"(%1) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_In_0"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_In_1"}> : (index) -> ()
    "aie.runtime_sequence"() <{sym_name = "f"}> ({
    ^bb0(%arg0: memref<32xi32>, %arg1: memref<32xi32>):
      %22 = "aiex.dma_configure_task_for"() <{alloc = @air_Out_0, issue_token = true}> ({
        "aie.dma_bd"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 32 : i32, static_offset = 0 : i32, static_sizes = array<i64: 32>, static_strides = array<i64: 1>}> : (memref<32xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%22) : (index) -> ()
      %24 = "aiex.dma_configure_task_for"() <{alloc = @air_In_0}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 16 : i32, static_offset = 0 : i32, static_sizes = array<i64: 16>, static_strides = array<i64: 1>}> : (memref<32xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%24) : (index) -> ()
      %25 = "aiex.dma_configure_task_for"() <{alloc = @air_In_1}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 16 : i32, static_offset = 16 : i32, static_sizes = array<i64: 16>, static_strides = array<i64: 1>}> : (memref<32xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%25) : (index) -> ()
      "aiex.dma_await_task"(%22) : (index) -> ()
      "aiex.dma_free_task"(%24) : (index) -> ()
      "aiex.dma_free_task"(%25) : (index) -> ()
    }) : () -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
}) : () -> ()
