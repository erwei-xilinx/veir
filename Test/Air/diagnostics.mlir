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

// Memory is not modelled, so an air.execute that allocates has no meaning here.
// RUN: not air-veir graph --allow-unregistered-dialect %S/Inputs/memref_in_execute.mlir 2>&1 | filecheck %s --check-prefix=MEMREF
// MEMREF: 'memref.alloc' in an air.execute body is not supported; only arith operations have a meaning here (memory is not modelled)

// AIR accepts an air.execute whose terminator yields the wrong type; so does the structure check,
// but the semantics refuses it.
// RUN: veir-opt %S/Inputs/terminator_mismatch.mlir > /dev/null
// RUN: not air-veir run %S/Inputs/terminator_mismatch.mlir 2>&1 | filecheck %s --check-prefix=YIELD
// YIELD: the terminator yields i32 as value #0, but the operation declares index

// Scopes: a loop carrying a token, and AIR's launch/segment/herd hierarchy.
// RUN: not air-veir graph --allow-unregistered-dialect %S/Inputs/scf_for.mlir 2>&1 | filecheck %s --check-prefix=LOOP
// LOOP: 'scf.for' opens a nested region or scope, which is not supported
// RUN: not air-veir reduce --allow-unregistered-dialect %S/fixture_prune_redundant_edges.mlir.in 2>&1 | filecheck %s --check-prefix=HIER
// HIER: operation #2 ('air.launch'): 'air.launch' opens a nested region or scope, which is not supported
