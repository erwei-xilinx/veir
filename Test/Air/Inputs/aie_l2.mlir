// aircc --device=npu2 --output-format=none on aie_l2.air.mlir.src (L1 via an L2 memtile).
"builtin.module"() ({
  "aie.device"() <{device = 8 : i32, sym_name = "seg"}> ({
    %0 = "aie.tile"() <{col = 1 : i32, row = 1 : i32}> : () -> index
    %1 = "aie.tile"() <{col = 0 : i32, row = 1 : i32}> : () -> index
    %2 = "aie.tile"() <{col = 0 : i32, row = 0 : i32}> : () -> index
    %3 = "aie.tile"() <{col = 0 : i32, row = 2 : i32}> : () -> index
    %4 = "aie.lock"(%3) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %5 = "aie.lock"(%3) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %6 = "aie.lock"(%3) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %7 = "aie.lock"(%3) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %8 = "aie.buffer"(%3) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<64xi32, 2>
    %9 = "aie.external_buffer"() <{sym_name = "__air_external_buffer"}> : () -> memref<64xi32>
    %10 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_1"}> : () -> memref<64xi32>
    %11 = "aie.mem"(%3) ({
      %30 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %31 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%7, %30) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%8) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 2>) -> ()
      "aie.use_lock"(%6, %30) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %32 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%4, %30) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%8) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 2>) -> ()
      "aie.use_lock"(%5, %30) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %12 = "aie.core"(%3) <{stack_size = 2048 : i32}> ({
      %29 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%6, %29) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%5, %29) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%4, %29) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%7, %29) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "h", air.herd_size = array<i64: 1, 1>} : (index) -> index
    %13 = "aie.lock"(%0) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %14 = "aie.lock"(%0) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %15 = "aie.lock"(%1) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %16 = "aie.lock"(%1) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %17 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf2"}> : (index) -> memref<64xi32, 1>
    %18 = "aie.buffer"(%0) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<64xi32, 1>
    "aie.flow"(%2, %1) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %3) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%3, %0) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%0, %2) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    %19 = "aie.memtile_dma"(%1) ({
      %26 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %27 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%16, %26) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%17) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 1>) -> ()
      "aie.use_lock"(%15, %26) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %28 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%15, %26) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%17) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 1>) -> ()
      "aie.use_lock"(%16, %26) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %20 = "aie.memtile_dma"(%0) ({
      %23 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %24 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%14, %23) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%18) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 1>) -> ()
      "aie.use_lock"(%13, %23) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %25 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%13, %23) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%18) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xi32, 1>) -> ()
      "aie.use_lock"(%14, %23) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    "aie.shim_dma_allocation"(%2) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_Out"}> : (index) -> ()
    "aie.shim_dma_allocation"(%2) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_In"}> : (index) -> ()
    "aie.runtime_sequence"() <{sym_name = "l2"}> ({
    ^bb0(%arg0: memref<64xi32>, %arg1: memref<64xi32>):
      %21 = "aiex.dma_configure_task_for"() <{alloc = @air_Out, issue_token = true}> ({
        "aie.dma_bd"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32, static_sizes = array<i64: 64>, static_strides = array<i64: 1>}> : (memref<64xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%21) : (index) -> ()
      %22 = "aiex.dma_configure_task_for"() <{alloc = @air_In}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32, static_sizes = array<i64: 64>, static_strides = array<i64: 1>}> : (memref<64xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%22) : (index) -> ()
      "aiex.dma_await_task"(%21) : (index) -> ()
      "aiex.dma_free_task"(%22) : (index) -> ()
    }) : () -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
}) : () -> ()
