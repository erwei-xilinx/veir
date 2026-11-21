// A 1x1 herd fed three L3 inputs as packets (mlir-air f7531d006, npu2), npu.air.mlir printed generic.
// The shim tasks carry the packet on their dma_bd; two shim channels feed one in-order S2MM ring.
"builtin.module"() ({
  "aie.device"() <{device = 8 : i32, sym_name = "seg"}> ({
    %0 = "aie.tile"() <{col = 0 : i32, row = 0 : i32}> : () -> index
    %1 = "aie.tile"() <{col = 0 : i32, row = 2 : i32}> : () -> index
    %2 = "aie.lock"(%1) <{init = 1 : i32, lockID = 7 : i32}> : (index) -> index
    %3 = "aie.lock"(%1) <{init = 0 : i32, lockID = 6 : i32}> : (index) -> index
    %4 = "aie.lock"(%1) <{init = 1 : i32, lockID = 5 : i32}> : (index) -> index
    %5 = "aie.lock"(%1) <{init = 0 : i32, lockID = 4 : i32}> : (index) -> index
    %6 = "aie.lock"(%1) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %7 = "aie.lock"(%1) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %8 = "aie.lock"(%1) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %9 = "aie.lock"(%1) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %10 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf3"}> : (index) -> memref<512xbf16, 2 : i32>
    %11 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf2"}> : (index) -> memref<4096xbf16, 2 : i32>
    %12 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<4096xbf16, 2 : i32>
    %13 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<1744xf32, 2 : i32>
    %14 = "aie.external_buffer"() <{sym_name = "__air_external_buffer"}> : () -> memref<512xbf16>
    %15 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_1"}> : () -> memref<4096xbf16>
    %16 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_2"}> : () -> memref<4096xbf16>
    %17 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_3"}> : () -> memref<1744xf32>
    %18 = "aie.mem"(%1) ({
      %25 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %26 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%9, %25) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%13) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 1744 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<1744xf32, 2 : i32>) -> ()
      "aie.use_lock"(%8, %25) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %27 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb6
      "aie.use_lock"(%6, %25) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%10) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 0>, static_len = 512 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<512xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%7, %25) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb5] : () -> ()
    ^bb5:  // pred: ^bb4
      "aie.use_lock"(%4, %25) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%11) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 1>, static_len = 4096 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4096xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%5, %25) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb6] : () -> ()
    ^bb6:  // pred: ^bb5
      "aie.use_lock"(%2, %25) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%12) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 2>, static_len = 4096 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4096xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%3, %25) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %19 = "aie.core"(%1) <{link_with = "probe_blk.o", stack_size = 8192 : i32}> ({
      %24 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%8, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%7, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%5, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%3, %24) <{action = 2 : i32}> : (index, i32) -> ()
      "func.call"(%10, %11, %12, %13) <{callee = @blk_probe}> : (memref<512xbf16, 2 : i32>, memref<4096xbf16, 2 : i32>, memref<4096xbf16, 2 : i32>, memref<1744xf32, 2 : i32>) -> ()
      "aie.use_lock"(%2, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%4, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%6, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%9, %24) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "h", air.herd_size = array<i64: 1, 1>} : (index) -> index
    "func.func"() <{function_type = (memref<512xbf16, 2 : i32>, memref<4096xbf16, 2 : i32>, memref<4096xbf16, 2 : i32>, memref<1744xf32, 2 : i32>) -> (), sym_name = "blk_probe", sym_visibility = "private"}> ({
    }) {link_with = "probe_blk.o", llvm.emit_c_interface} : () -> ()
    "aie.packet_flow"() <{ID = 0 : i8}> ({
      "aie.packet_source"(%0) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.packet_dest"(%1) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.end"() : () -> ()
    }) : () -> ()
    "aie.packet_flow"() <{ID = 1 : i8}> ({
      "aie.packet_source"(%0) <{bundle = 1 : i32, channel = 1 : i32}> : (index) -> ()
      "aie.packet_dest"(%1) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.end"() : () -> ()
    }) : () -> ()
    "aie.packet_flow"() <{ID = 2 : i8}> ({
      "aie.packet_source"(%0) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.packet_dest"(%1) <{bundle = 1 : i32, channel = 0 : i32}> : (index) -> ()
      "aie.end"() : () -> ()
    }) : () -> ()
    "aie.flow"(%1, %0) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_channel_3"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_channel_0"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 1 : i32, channel_index = 1 : i64, plio = false, sym_name = "air_channel_1"}> : (index) -> ()
    "aie.shim_dma_allocation"(%0) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_channel_2"}> : (index) -> ()
    "aie.runtime_sequence"() <{sym_name = "probe"}> ({
    ^bb0(%arg0: memref<512xbf16>, %arg1: memref<4096xbf16>, %arg2: memref<4096xbf16>, %arg3: memref<1744xf32>):
      %20 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_3, issue_token = true}> ({
        "aie.dma_bd"(%arg3) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 1744 : i32, static_offset = 0 : i32, static_sizes = array<i64: 1744>, static_strides = array<i64: 1>}> : (memref<1744xf32>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%20) : (index) -> ()
      %21 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_0}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 0>, static_len = 512 : i32, static_offset = 0 : i32, static_sizes = array<i64: 512>, static_strides = array<i64: 1>}> : (memref<512xbf16>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%21) : (index) -> ()
      %22 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_1}> ({
        "aie.dma_bd"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 1>, static_len = 4096 : i32, static_offset = 0 : i32, static_sizes = array<i64: 4096>, static_strides = array<i64: 1>}> : (memref<4096xbf16>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%22) : (index) -> ()
      %23 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_0}> ({
        "aie.dma_bd"(%arg2) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, packet = #aie.packet_info<pkt_id = 2>, static_len = 4096 : i32, static_offset = 0 : i32, static_sizes = array<i64: 4096>, static_strides = array<i64: 1>}> : (memref<4096xbf16>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%23) : (index) -> ()
      "aiex.dma_await_task"(%20) : (index) -> ()
      "aiex.dma_free_task"(%21) : (index) -> ()
      "aiex.dma_free_task"(%22) : (index) -> ()
      "aiex.dma_free_task"(%23) : (index) -> ()
    }) : () -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
}) : () -> ()
