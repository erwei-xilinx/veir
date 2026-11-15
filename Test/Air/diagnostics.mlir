// What is outside the supported subset is refused, each with a message naming the reason --
// never interpreted as a no-op.

// A cycle is a use before definition; the verifier rejects it, as air-opt does.
// RUN: not air-veir graph %S/Inputs/cycle.mlir 2>&1 | filecheck %s --check-prefix=CYCLE
// CYCLE: air.wait_all: operand #0 does not dominate this use

// A token that crosses a region boundary as a block argument.
// RUN: not air-veir graph %S/Inputs/token_block_arg.mlir 2>&1 | filecheck %s --check-prefix=BLOCKARG
// BLOCKARG: a token that is a block argument is not supported

// A dependency operand that is not a token, as AIR's ODS also refuses.
// RUN: not veir-opt %S/Inputs/token_wrong_type.mlir 2>&1 | filecheck %s --check-prefix=TYPE
// TYPE: air.wait_all: operand #0 must be an async token, but got index

// The `!air.token` of docs/AIRComputeModel.md is not a type the dialect has.
// RUN: not veir-opt %S/Inputs/unknown_type.mlir 2>&1 | filecheck %s --check-prefix=UNKNOWN
// UNKNOWN: type '!air.token' is not registered

// Layer 2 refuses what it has not been given a meaning for yet.
// A DMA without async is synchronous (D24): it runs, and orders what comes after it.
// RUN: air-veir graph --allow-unregistered-dialect %S/Inputs/blocking_dma.mlir | filecheck %s --check-prefix=SYNCDMA
// SYNCDMA: event 0: air.dma_memcpy_nd (blocking) waits for [], keeps []
// RUN: not air-veir graph --allow-unregistered-dialect %S/Inputs/refuse_dma_on_view.mlir 2>&1 | filecheck %s --check-prefix=VIEW
// VIEW: a DMA on a view is not supported; fold the view into the pattern first
// A host memref.dealloc is a blocking event since D45 (sync_ops.mlir).

// Memory inside an air.execute is modelled since layer 2.
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/memref_in_execute.mlir | filecheck %s --check-prefix=MEMREF
// MEMREF: @f: event 0 = [buffer 0]

// AIR accepts an air.execute whose terminator yields the wrong type; so does the structure check,
// but the semantics refuses it.
// RUN: veir-opt %S/Inputs/terminator_mismatch.mlir > /dev/null
// RUN: not air-veir run %S/Inputs/terminator_mismatch.mlir 2>&1 | filecheck %s --check-prefix=YIELD
// YIELD: the terminator yields i32 as value #0, but the operation declares index

// Scopes: AIR's launch/segment/herd hierarchy is instantiated since layer 5 (hierarchy.mlir),
// but reduce does not rewrite it.
// RUN: not air-veir reduce --allow-unregistered-dialect %S/fixture_prune_redundant_edges.mlir.in 2>&1 | filecheck %s --check-prefix=HIER
// HIER: reduce does not support air.launch/segment/herd/rank yet
