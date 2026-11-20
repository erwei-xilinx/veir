"builtin.module"() ({
  "func.func"() <{function_type = (memref<4xi32>, memref<4xi32>) -> (), sym_name = "snapshot"}> ({
  ^bb0(%arg2: memref<4xi32>, %arg3: memref<4xi32>):
    %3 = "arith.constant"() <{value = 0 : index}> : () -> index
    %4 = "arith.constant"() <{value = 7 : i32}> : () -> i32
    %5 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    "memref.copy"(%arg2, %5) : (memref<4xi32>, memref<4xi32>) -> ()
    %6 = "bufferization.to_tensor"(%5) <{restrict, writable}> : (memref<4xi32>) -> tensor<4xi32>
    "memref.store"(%4, %arg2, %3) : (i32, memref<4xi32>, index) -> ()
    "bufferization.materialize_in_destination"(%6, %arg3) <{writable}> : (tensor<4xi32>, memref<4xi32>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
  "func.func"() <{function_type = (memref<4xi32>, memref<8xi32>) -> (), sym_name = "into_view"}> ({
  ^bb0(%arg0: memref<4xi32>, %arg1: memref<8xi32>):
    %0 = "memref.alloc"() <{operandSegmentSizes = array<i32: 0, 0>}> : () -> memref<4xi32>
    "memref.copy"(%arg0, %0) : (memref<4xi32>, memref<4xi32>) -> ()
    %1 = "bufferization.to_tensor"(%0) <{restrict, writable}> : (memref<4xi32>) -> tensor<4xi32>
    %2 = "memref.subview"(%arg1) <{operandSegmentSizes = array<i32: 1, 0, 0, 0>, static_offsets = array<i64: 2>, static_sizes = array<i64: 4>, static_strides = array<i64: 1>}> : (memref<8xi32>) -> memref<4xi32, strided<[1], offset: 2>>
    "bufferization.materialize_in_destination"(%1, %2) <{writable}> : (tensor<4xi32>, memref<4xi32, strided<[1], offset: 2>>) -> ()
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
