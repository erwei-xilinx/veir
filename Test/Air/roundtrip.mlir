// Real AIR test inputs, printed generically by air-opt, survive two trips through VeIR with
// their tokens, dependency operands, regions and discardable attributes intact. The registered
// subset needs no flag; air.launch, air.herd, air.dma_memcpy_nd and memref.* are kept as
// unregistered operations. Re-verification by air-opt itself is in air-roundtrip.sh.

// RUN: veir-opt --print-op-generic %S/fixture_air_execute.mlir.in | veir-opt --print-op-generic | filecheck %s --check-prefix=EXEC
// RUN: veir-opt --print-op-generic %S/fixture_air_wait_async.mlir.in | veir-opt --print-op-generic | filecheck %s --check-prefix=WAIT
// RUN: veir-opt --print-op-generic --allow-unregistered-dialect %S/fixture_prune_redundant_edges.mlir.in | veir-opt --print-op-generic --allow-unregistered-dialect | filecheck %s --check-prefix=PRUNE
// RUN: not veir-opt %S/fixture_prune_redundant_edges.mlir.in 2>&1 | filecheck %s --check-prefix=UNREG

// EXEC:      %[[A:[^ ]+]]:2 = "air.execute"() ({
// EXEC:        "air.execute_terminator"(%{{.*}}) : (index) -> ()
// EXEC-NEXT: }) : () -> (!air.async.token, index)
// EXEC-NEXT: %[[E:[^ ]+]] = "air.wait_all"() : () -> !air.async.token
// EXEC-NEXT: "air.execute"(%[[E]]) ({
// EXEC:      }) {"foo" = "bar"} : (!air.async.token) -> !air.async.token
// EXEC:      %[[B:[^ ]+]]:2 = "air.execute"() ({
// EXEC:      }) {"id" = 1 : i64} : () -> (!air.async.token, index)
// EXEC:      "air.execute"(%[[E]], %[[B]]#0) ({
// EXEC:      }) : (!air.async.token, !air.async.token) -> (!air.async.token, index, i32)

// WAIT:      "air.wait_all"() : () -> ()
// WAIT-NEXT: %[[W0:[^ ]+]] = "air.wait_all"() : () -> !air.async.token
// WAIT-NEXT: %[[W1:[^ ]+]] = "air.wait_all"(%[[W0]]) : (!air.async.token) -> !air.async.token
// WAIT-NEXT: %[[W2:[^ ]+]] = "air.wait_all"(%[[W0]], %[[W1]]) : (!air.async.token, !air.async.token) -> !air.async.token
// WAIT-NEXT: "func.return"(%[[W2]]) : (!air.async.token) -> ()

// PRUNE:     "func.func"() <{"function_type" = (memref<1024xi32>) -> (), "sym_name" = "foo"}>
// PRUNE:     "air.launch"(%{{.*}}) <{"operandSegmentSizes" = array<i32: 0, 2, 1>}>
// PRUNE:     %[[ALLOC:[^ ]+]]:2 = "air.execute"() ({
// PRUNE:       "memref.alloc"() <{"operandSegmentSizes" = array<i32: 0, 0>}> : () -> memref<512xi32>
// PRUNE:     "air.dma_memcpy_nd"(%[[ALLOC]]#0, %[[ALLOC]]#1, {{.*}}"static_src_offsets" = array<i64: -9223372036854775808>
// PRUNE:     "air.herd"(
// PRUNE:     }) {"id" = 4 : i32} : (!air.async.token, !air.async.token) -> !air.async.token
// PRUNE:     "air.herd_terminator"() : () -> ()
// PRUNE:     {"id" = 3 : i32} : (index, index, memref<1024xi32>) -> !air.async.token

// UNREG: op 'air.launch' is not registered
