// aircc --device=npu2 --output-format=none on aie_copy_relay.air.mlir.src; npu.*.mlir printed generic.
"builtin.module"() ({
  "aie.device"() <{device = 8 : i32, sym_name = "seg"}> ({
    %0 = "aie.tile"() <{col = 0 : i32, row = 0 : i32}> : () -> index
    %1 = "aie.tile"() <{col = 0 : i32, row = 2 : i32}> : () -> index
    %2 = "aie.lock"(%1) <{init = 2 : i32, lockID = 3 : i32}> : (index) -> index
    %3 = "aie.lock"(%1) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %4 = "aie.lock"(%1) <{init = 2 : i32, lockID = 1 : i32}> : (index) -> index
    %5 = "aie.lock"(%1) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %6 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf3"}> : (index) -> memref<8xi32, 2>
    %7 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf2"}> : (index) -> memref<8xi32, 2>
    %8 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<8xi32, 2>
    %9 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<8xi32, 2>
    %10 = "aie.external_buffer"() <{sym_name = "__air_external_buffer"}> : () -> memref<32xi32>
    %11 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_1"}> : () -> memref<32xi32>
    %12 = "aie.mem"(%1) ({
      %24 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %25 = "aie.dma_start"()[^bb1, ^bb4] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb2
      "aie.use_lock"(%5, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%9) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 8 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<8xi32, 2>) -> ()
      "aie.use_lock"(%4, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb2] : () -> ()
    ^bb2:  // pred: ^bb1
      "aie.use_lock"(%5, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%6) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 8 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<8xi32, 2>) -> ()
      "aie.use_lock"(%4, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb3:  // pred: ^bb4
      "aie.end"() : () -> ()
    ^bb4:  // pred: ^bb0
      %26 = "aie.dma_start"()[^bb5, ^bb3] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb5:  // 2 preds: ^bb4, ^bb6
      "aie.use_lock"(%2, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%8) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 8 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<8xi32, 2>) -> ()
      "aie.use_lock"(%3, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb6] : () -> ()
    ^bb6:  // pred: ^bb5
      "aie.use_lock"(%2, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%7) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 8 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<8xi32, 2>) -> ()
      "aie.use_lock"(%3, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb5] : () -> ()
    }) : (index) -> index
    %13 = "aie.core"(%1) <{stack_size = 2048 : i32}> ({
      %16 = "arith.constant"() <{value = 1 : index}> : () -> index
      %17 = "arith.constant"() <{value = 8 : index}> : () -> index
      %18 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %19 = "arith.constant"() <{value = 4 : index}> : () -> index
      %20 = "arith.constant"() <{value = 2 : index}> : () -> index
      %21 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "scf.for"(%21, %19, %20) ({
      ^bb0(%arg2: index):
        "aie.use_lock"(%4, %18) <{action = 2 : i32}> : (index, i32) -> ()
        "aie.use_lock"(%4, %18) <{action = 2 : i32}> : (index, i32) -> ()
        "aie.use_lock"(%3, %18) <{action = 2 : i32}> : (index, i32) -> ()
        "scf.for"(%21, %17, %16) ({
        ^bb0(%arg4: index):
          %23 = "memref.load"(%8, %arg4) : (memref<8xi32, 2>, index) -> i32
          "memref.store"(%23, %9, %arg4) : (i32, memref<8xi32, 2>, index) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "aie.use_lock"(%2, %18) <{action = 1 : i32}> : (index, i32) -> ()
        "aie.use_lock"(%3, %18) <{action = 2 : i32}> : (index, i32) -> ()
        "scf.for"(%21, %17, %16) ({
        ^bb0(%arg3: index):
          %22 = "memref.load"(%7, %arg3) : (memref<8xi32, 2>, index) -> i32
          "memref.store"(%22, %6, %arg3) : (i32, memref<8xi32, 2>, index) -> ()
          "scf.yield"() : () -> ()
        }) : (index, index, index) -> ()
        "aie.use_lock"(%2, %18) <{action = 1 : i32}> : (index, i32) -> ()
        "aie.use_lock"(%5, %18) <{action = 1 : i32}> : (index, i32) -> ()
        "aie.use_lock"(%5, %18) <{action = 1 : i32}> : (index, i32) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "h", air.herd_size = array<i64: 1, 1>} : (index) -> index
    "aie.flow"(%0, %1) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %0) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_Out"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_In"}> : (index) -> ()
    "aie.runtime_sequence"() <{sym_name = "f"}> ({
    ^bb0(%arg0: memref<32xi32>, %arg1: memref<32xi32>):
      %14 = "aiex.dma_configure_task_for"() <{alloc = @air_Out, issue_token = true}> ({
        "aie.dma_bd"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 32 : i32, static_offset = 0 : i32, static_sizes = array<i64: 32>, static_strides = array<i64: 1>}> : (memref<32xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%14) : (index) -> ()
      %15 = "aiex.dma_configure_task_for"() <{alloc = @air_In}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 32 : i32, static_offset = 0 : i32, static_sizes = array<i64: 32>, static_strides = array<i64: 1>}> : (memref<32xi32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%15) : (index) -> ()
      "aiex.dma_await_task"(%14) : (index) -> ()
      "aiex.dma_free_task"(%15) : (index) -> ()
    }) : () -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
}) : () -> ()
