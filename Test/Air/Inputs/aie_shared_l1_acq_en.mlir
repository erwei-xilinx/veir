// mlir-air programming_examples/shared_l1_single_herd (mlir-air f7531d006, npu2), npu.air.mlir printed generic.
// The memtile's S2MM chain releases its consumers' locks in BDs whose acquire has acq_en = false (T14).
"builtin.module"() ({
  "aie.device"() <{device = 8 : i32, sym_name = "seg"}> ({
    %0 = "aie.tile"() <{col = 1 : i32, row = 1 : i32}> : () -> index
    %1 = "aie.tile"() <{col = 0 : i32, row = 1 : i32}> : () -> index
    %2 = "aie.tile"() <{col = 0 : i32, row = 0 : i32}> : () -> index
    %3 = "aie.tile"() <{col = 0 : i32, row = 2 : i32}> : () -> index
    %4 = "aie.tile"() <{col = 0 : i32, row = 3 : i32}> : () -> index
    %5 = "aie.tile"() <{col = 0 : i32, row = 4 : i32}> : () -> index
    %6 = "aie.tile"() <{col = 0 : i32, row = 5 : i32}> : () -> index
    %7 = "aie.lock"(%3) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %8 = "aie.lock"(%3) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %9 = "aie.lock"(%4) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %10 = "aie.lock"(%4) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %11 = "aie.lock"(%5) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %12 = "aie.lock"(%5) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %13 = "aie.lock"(%6) <{init = 1 : i32, lockID = 5 : i32}> : (index) -> index
    %14 = "aie.lock"(%6) <{init = 0 : i32, lockID = 4 : i32}> : (index) -> index
    %15 = "aie.lock"(%6) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %16 = "aie.lock"(%6) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %17 = "aie.buffer"(%6) <{aligned = true, sym_name = "buf3"}> : (index) -> memref<64xbf16, 2 : i32>
    %18 = "aie.buffer"(%5) <{aligned = true, sym_name = "buf2"}> : (index) -> memref<64xbf16, 2 : i32>
    %19 = "aie.buffer"(%4) <{aligned = true, sym_name = "buf1"}> : (index) -> memref<64xbf16, 2 : i32>
    %20 = "aie.buffer"(%3) <{aligned = true, sym_name = "buf0"}> : (index) -> memref<64xbf16, 2 : i32>
    %21 = "aie.external_buffer"() <{sym_name = "__air_external_buffer"}> : () -> memref<4x64xbf16>
    %22 = "aie.external_buffer"() <{sym_name = "__air_external_buffer_1"}> : () -> memref<1x64xbf16>
    %23 = "aie.lock"(%6) <{init = 0 : i32, lockID = 1 : i32, sym_name = "shared_l12_cons_lock"}> : (index) -> index
    %24 = "aie.lock"(%6) <{init = 1 : i32, lockID = 0 : i32, sym_name = "shared_l12_prod_lock"}> : (index) -> index
    %25 = "aie.buffer"(%6) <{aligned = true, sym_name = "shared_l12"}> : (index) -> memref<64xbf16, 2 : i32>
    %26 = "aie.lock"(%5) <{init = 0 : i32, lockID = 1 : i32, sym_name = "shared_l11_cons_lock"}> : (index) -> index
    %27 = "aie.lock"(%5) <{init = 1 : i32, lockID = 0 : i32, sym_name = "shared_l11_prod_lock"}> : (index) -> index
    %28 = "aie.buffer"(%5) <{aligned = true, sym_name = "shared_l11"}> : (index) -> memref<64xbf16, 2 : i32>
    %29 = "aie.lock"(%4) <{init = 0 : i32, lockID = 1 : i32, sym_name = "shared_l10_cons_lock"}> : (index) -> index
    %30 = "aie.lock"(%4) <{init = 1 : i32, lockID = 0 : i32, sym_name = "shared_l10_prod_lock"}> : (index) -> index
    %31 = "aie.buffer"(%4) <{aligned = true, sym_name = "shared_l10"}> : (index) -> memref<64xbf16, 2 : i32>
    %32 = "aie.mem"(%6) ({
      %136 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %137 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%16, %136) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%17) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%15, %136) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %138 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%13, %136) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%17) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%14, %136) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %33 = "aie.core"(%6) <{stack_size = 2048 : i32}> ({
      %120 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %121 = "arith.constant"() <{value = 2 : index}> : () -> index
      %122 = "arith.constant"() <{value = 1.000000e+01 : bf16}> : () -> bf16
      %123 = "arith.constant"() <{value = 1.000000e+00 : bf16}> : () -> bf16
      %124 = "arith.constant"() <{value = 0.000000e+00 : bf16}> : () -> bf16
      %125 = "arith.constant"() <{value = 64 : index}> : () -> index
      %126 = "arith.constant"() <{value = 16 : index}> : () -> index
      %127 = "arith.constant"() <{value = 1 : index}> : () -> index
      %128 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%15, %120) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%14, %120) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%128, %121, %127) ({
      ^bb0(%arg14: index):
        %132 = "scf.index_switch"(%arg14) <{cases = array<i64: 0>}> ({
          "scf.yield"(%122) : (bf16) -> ()
        }, {
          "scf.yield"(%123) : (bf16) -> ()
        }) : (index) -> bf16
        "scf.for"(%128, %125, %126) ({
        ^bb0(%arg15: index):
          %133 = "vector.transfer_read"(%17, %arg15, %124) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
          %134 = "vector.broadcast"(%132) : (bf16) -> vector<16xbf16>
          %135 = "arith.addf"(%133, %134) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
          "vector.transfer_write"(%135, %17, %arg15) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
          "scf.yield"() : () -> ()
        }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%128, %125, %126) ({
      ^bb0(%arg13: index):
        %129 = "vector.transfer_read"(%17, %arg13, %124) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%23, %120) <{action = 2 : i32}> : (index, i32) -> ()
        %130 = "vector.transfer_read"(%25, %arg13, %124) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%24, %120) <{action = 1 : i32}> : (index, i32) -> ()
        %131 = "arith.addf"(%129, %130) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
        "vector.transfer_write"(%131, %17, %arg13) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "aie.use_lock"(%13, %120) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.use_lock"(%16, %120) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 3>, air.herd_name = "col_relay", air.herd_size = array<i64: 1, 4>} : (index) -> index
    %34 = "aie.mem"(%5) ({
      %118 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %119 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%11, %118) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%18) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%12, %118) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %35 = "aie.core"(%5) <{stack_size = 2048 : i32}> ({
      %101 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %102 = "arith.constant"() <{value = 1.000000e+01 : bf16}> : () -> bf16
      %103 = "arith.constant"() <{value = 1.000000e+00 : bf16}> : () -> bf16
      %104 = "arith.constant"() <{value = 0.000000e+00 : bf16}> : () -> bf16
      %105 = "arith.constant"() <{value = 64 : index}> : () -> index
      %106 = "arith.constant"() <{value = 16 : index}> : () -> index
      %107 = "arith.constant"() <{value = 1 : index}> : () -> index
      %108 = "arith.constant"() <{value = 2 : index}> : () -> index
      %109 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%12, %101) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%109, %108, %107) ({
      ^bb0(%arg11: index):
        %114 = "scf.index_switch"(%arg11) <{cases = array<i64: 0>}> ({
          "scf.yield"(%102) : (bf16) -> ()
        }, {
          "scf.yield"(%103) : (bf16) -> ()
        }) : (index) -> bf16
        "scf.for"(%109, %105, %106) ({
        ^bb0(%arg12: index):
          %115 = "vector.transfer_read"(%18, %arg12, %104) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
          %116 = "vector.broadcast"(%114) : (bf16) -> vector<16xbf16>
          %117 = "arith.addf"(%115, %116) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
          "vector.transfer_write"(%117, %18, %arg12) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
          "scf.yield"() : () -> ()
        }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%109, %105, %106) ({
      ^bb0(%arg10: index):
        %111 = "vector.transfer_read"(%18, %arg10, %104) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%26, %101) <{action = 2 : i32}> : (index, i32) -> ()
        %112 = "vector.transfer_read"(%28, %arg10, %104) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%27, %101) <{action = 1 : i32}> : (index, i32) -> ()
        %113 = "arith.addf"(%111, %112) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
        "vector.transfer_write"(%113, %18, %arg10) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%109, %105, %106) ({
      ^bb0(%arg9: index):
        %110 = "vector.transfer_read"(%18, %arg9, %104) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%24, %101) <{action = 2 : i32}> : (index, i32) -> ()
        "vector.transfer_write"(%110, %25, %arg9) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "aie.use_lock"(%23, %101) <{action = 1 : i32}> : (index, i32) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "aie.use_lock"(%11, %101) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 2>, air.herd_name = "col_relay", air.herd_size = array<i64: 1, 4>} : (index) -> index
    %36 = "aie.mem"(%4) ({
      %99 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %100 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%9, %99) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%19) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%10, %99) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %37 = "aie.core"(%4) <{stack_size = 2048 : i32}> ({
      %82 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %83 = "arith.constant"() <{value = 2 : index}> : () -> index
      %84 = "arith.constant"() <{value = 1.000000e+01 : bf16}> : () -> bf16
      %85 = "arith.constant"() <{value = 1.000000e+00 : bf16}> : () -> bf16
      %86 = "arith.constant"() <{value = 0.000000e+00 : bf16}> : () -> bf16
      %87 = "arith.constant"() <{value = 64 : index}> : () -> index
      %88 = "arith.constant"() <{value = 16 : index}> : () -> index
      %89 = "arith.constant"() <{value = 1 : index}> : () -> index
      %90 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%10, %82) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%90, %83, %89) ({
      ^bb0(%arg7: index):
        %95 = "scf.index_switch"(%arg7) <{cases = array<i64: 0>}> ({
          "scf.yield"(%84) : (bf16) -> ()
        }, {
          "scf.yield"(%85) : (bf16) -> ()
        }) : (index) -> bf16
        "scf.for"(%90, %87, %88) ({
        ^bb0(%arg8: index):
          %96 = "vector.transfer_read"(%19, %arg8, %86) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
          %97 = "vector.broadcast"(%95) : (bf16) -> vector<16xbf16>
          %98 = "arith.addf"(%96, %97) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
          "vector.transfer_write"(%98, %19, %arg8) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
          "scf.yield"() : () -> ()
        }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%90, %87, %88) ({
      ^bb0(%arg6: index):
        %92 = "vector.transfer_read"(%19, %arg6, %86) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%29, %82) <{action = 2 : i32}> : (index, i32) -> ()
        %93 = "vector.transfer_read"(%31, %arg6, %86) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%30, %82) <{action = 1 : i32}> : (index, i32) -> ()
        %94 = "arith.addf"(%92, %93) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
        "vector.transfer_write"(%94, %19, %arg6) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%90, %87, %88) ({
      ^bb0(%arg5: index):
        %91 = "vector.transfer_read"(%19, %arg5, %86) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%27, %82) <{action = 2 : i32}> : (index, i32) -> ()
        "vector.transfer_write"(%91, %28, %arg5) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "aie.use_lock"(%26, %82) <{action = 1 : i32}> : (index, i32) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "aie.use_lock"(%9, %82) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 1>, air.herd_name = "col_relay", air.herd_size = array<i64: 1, 4>} : (index) -> index
    %38 = "aie.mem"(%3) ({
      %80 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %81 = "aie.dma_start"()[^bb1, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%7, %80) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%20) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<64xbf16, 2 : i32>) -> ()
      "aie.use_lock"(%8, %80) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb0
      "aie.end"() : () -> ()
    }) : (index) -> index
    %39 = "aie.core"(%3) <{stack_size = 2048 : i32}> ({
      %66 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %67 = "arith.constant"() <{value = 2 : index}> : () -> index
      %68 = "arith.constant"() <{value = 1.000000e+01 : bf16}> : () -> bf16
      %69 = "arith.constant"() <{value = 1.000000e+00 : bf16}> : () -> bf16
      %70 = "arith.constant"() <{value = 0.000000e+00 : bf16}> : () -> bf16
      %71 = "arith.constant"() <{value = 64 : index}> : () -> index
      %72 = "arith.constant"() <{value = 16 : index}> : () -> index
      %73 = "arith.constant"() <{value = 1 : index}> : () -> index
      %74 = "arith.constant"() <{value = 0 : index}> : () -> index
      "cf.br"()[^bb1] : () -> ()
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%8, %66) <{action = 2 : i32}> : (index, i32) -> ()
      "scf.for"(%74, %67, %73) ({
      ^bb0(%arg3: index):
        %76 = "scf.index_switch"(%arg3) <{cases = array<i64: 0>}> ({
          "scf.yield"(%68) : (bf16) -> ()
        }, {
          "scf.yield"(%69) : (bf16) -> ()
        }) : (index) -> bf16
        "scf.for"(%74, %71, %72) ({
        ^bb0(%arg4: index):
          %77 = "vector.transfer_read"(%20, %arg4, %70) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
          %78 = "vector.broadcast"(%76) : (bf16) -> vector<16xbf16>
          %79 = "arith.addf"(%77, %78) <{fastmath = #arith.fastmath<none>}> : (vector<16xbf16>, vector<16xbf16>) -> vector<16xbf16>
          "vector.transfer_write"(%79, %20, %arg4) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
          "scf.yield"() : () -> ()
        }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "scf.for"(%74, %71, %72) ({
      ^bb0(%arg2: index):
        %75 = "vector.transfer_read"(%20, %arg2, %70) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (memref<64xbf16, 2 : i32>, index, bf16) -> vector<16xbf16>
        "aie.use_lock"(%30, %66) <{action = 2 : i32}> : (index, i32) -> ()
        "vector.transfer_write"(%75, %31, %arg2) <{in_bounds = [true], operandSegmentSizes = array<i32: 1, 1, 1, 0>, permutation_map = affine_map<(d0) -> (d0)>}> : (vector<16xbf16>, memref<64xbf16, 2 : i32>, index) -> ()
        "aie.use_lock"(%29, %66) <{action = 1 : i32}> : (index, i32) -> ()
        "scf.yield"() : () -> ()
      }) {loop_annotation = #llvm.loop_annotation<mustProgress = true>} : (index, index, index) -> ()
      "aie.use_lock"(%7, %66) <{action = 1 : i32}> : (index, i32) -> ()
      "cf.br"()[^bb1] : () -> ()
    }) {air.herd_local_id = array<i64: 0, 0>, air.herd_name = "col_relay", air.herd_size = array<i64: 1, 4>} : (index) -> index
    %40 = "aie.lock"(%1) <{init = 1 : i32, lockID = 7 : i32}> : (index) -> index
    %41 = "aie.lock"(%1) <{init = 0 : i32, lockID = 6 : i32}> : (index) -> index
    %42 = "aie.lock"(%1) <{init = 1 : i32, lockID = 5 : i32}> : (index) -> index
    %43 = "aie.lock"(%1) <{init = 0 : i32, lockID = 4 : i32}> : (index) -> index
    %44 = "aie.lock"(%1) <{init = 1 : i32, lockID = 3 : i32}> : (index) -> index
    %45 = "aie.lock"(%1) <{init = 0 : i32, lockID = 2 : i32}> : (index) -> index
    %46 = "aie.lock"(%1) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %47 = "aie.lock"(%1) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %48 = "aie.lock"(%0) <{init = 1 : i32, lockID = 1 : i32}> : (index) -> index
    %49 = "aie.lock"(%0) <{init = 0 : i32, lockID = 0 : i32}> : (index) -> index
    %50 = "aie.buffer"(%1) <{aligned = true, sym_name = "buf5"}> : (index) -> memref<4x64xbf16, 1 : i32>
    %51 = "aie.buffer"(%0) <{aligned = true, sym_name = "buf4"}> {air.counted_lock} : (index) -> memref<1x64xbf16, 1 : i32>
    "aie.flow"(%2, %1) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%0, %2) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %3) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %4) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 1 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %5) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 2 : i32}> : (index, index) -> ()
    "aie.flow"(%1, %6) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 3 : i32}> : (index, index) -> ()
    "aie.flow"(%6, %0) <{dest_bundle = 1 : i32, dest_channel = 0 : i32, source_bundle = 1 : i32, source_channel = 0 : i32}> : (index, index) -> ()
    %52 = "aie.memtile_dma"(%0) ({
      %63 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %64 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%49, %63) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%51) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<1x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%48, %63) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb3
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %65 = "aie.dma_start"()[^bb4, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%48, %63) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%51) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<1x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%49, %63) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    }) : (index) -> index
    %53 = "aie.memtile_dma"(%1) ({
      %56 = "arith.constant"() <{value = 0 : i32}> : () -> i32
      %57 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      %58 = "aie.dma_start"()[^bb1, ^bb3] <{channel = 0 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb1:  // 2 preds: ^bb0, ^bb1
      "aie.use_lock"(%47, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%46, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb1] : () -> ()
    ^bb2:  // pred: ^bb9
      "aie.end"() : () -> ()
    ^bb3:  // pred: ^bb0
      %59 = "aie.dma_start"()[^bb4, ^bb5] <{channel = 1 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb4:  // 2 preds: ^bb3, ^bb4
      "aie.use_lock"(%45, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 64 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%44, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb4] : () -> ()
    ^bb5:  // pred: ^bb3
      %60 = "aie.dma_start"()[^bb6, ^bb7] <{channel = 2 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb6:  // 2 preds: ^bb5, ^bb6
      "aie.use_lock"(%43, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 128 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%42, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb6] : () -> ()
    ^bb7:  // pred: ^bb5
      %61 = "aie.dma_start"()[^bb8, ^bb9] <{channel = 3 : i32, channel_dir = 1 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb8:  // 2 preds: ^bb7, ^bb8
      "aie.use_lock"(%41, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 192 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%40, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb8] : () -> ()
    ^bb9:  // pred: ^bb7
      %62 = "aie.dma_start"()[^bb10, ^bb2] <{channel = 0 : i32, channel_dir = 0 : i32, repeat_count = 0 : i32}> : () -> i1
    ^bb10:  // 2 preds: ^bb9, ^bb16
      "aie.use_lock"(%44, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%45, %56) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb11] : () -> ()
    ^bb11:  // pred: ^bb10
      "aie.use_lock"(%42, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%43, %56) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb12] : () -> ()
    ^bb12:  // pred: ^bb11
      "aie.use_lock"(%40, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%41, %56) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb13] : () -> ()
    ^bb13:  // pred: ^bb12
      "aie.use_lock"(%46, %57) <{action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 256 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%47, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb14] : () -> ()
    ^bb14:  // pred: ^bb13
      "aie.use_lock"(%44, %57) <{acq_en = false, action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%45, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb15] : () -> ()
    ^bb15:  // pred: ^bb14
      "aie.use_lock"(%42, %57) <{acq_en = false, action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%43, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb16] : () -> ()
    ^bb16:  // pred: ^bb15
      "aie.use_lock"(%40, %57) <{acq_en = false, action = 2 : i32}> : (index, i32) -> ()
      "aie.dma_bd"(%50) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 0 : i32, static_offset = 0 : i32}> {task_id = 0 : i32} : (memref<4x64xbf16, 1 : i32>) -> ()
      "aie.use_lock"(%41, %57) <{action = 1 : i32}> : (index, i32) -> ()
      "aie.next_bd"()[^bb10] : () -> ()
    }) : (index) -> index
    "aie.shim_dma_allocation"(%2) <{channel_dir = 0 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_channel_1"}> : (index) -> ()
    "aie.shim_dma_allocation"(%2) <{channel_dir = 1 : i32, channel_index = 0 : i64, plio = false, sym_name = "air_channel_0"}> : (index) -> ()
    "aie.runtime_sequence"() <{sym_name = "col_relay"}> ({
    ^bb0(%arg0: memref<4x64xbf16>, %arg1: memref<1x64xbf16>):
      %54 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_1, issue_token = true}> ({
        "aie.dma_bd"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 64 : i32, static_offset = 0 : i32, static_sizes = array<i64: 64>, static_strides = array<i64: 1>}> : (memref<1x64xbf16>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%54) : (index) -> ()
      %55 = "aiex.dma_configure_task_for"() <{alloc = @air_channel_0}> ({
        "aie.dma_bd"(%arg0) <{operandSegmentSizes = array<i32: 1, 0, 0, 0, 0, 0>, static_len = 256 : i32, static_offset = 0 : i32, static_sizes = array<i64: 256>, static_strides = array<i64: 1>}> : (memref<4x64xbf16>) -> ()
        "aie.end"() : () -> ()
      }) : () -> index
      "aiex.dma_start_task"(%55) : (index) -> ()
      "aiex.dma_await_task"(%54) : (index) -> ()
      "aiex.dma_free_task"(%55) : (index) -> ()
    }) : () -> ()
    "aie.end"() : () -> ()
  }) {dlti.dl_spec = #dlti.dl_spec<index = 32 : i64>} : () -> ()
}) : () -> ()
