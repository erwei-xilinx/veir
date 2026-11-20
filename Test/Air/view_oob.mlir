// A view whose operands are known and that reaches outside its source is refused, as a transfer
// out of bounds is: a reinterpret_cast past the end of its buffer, and a subview past the end of
// a row (which, linearized, would land in the next row). The cases are in
// Inputs/view_oob_cast.air.mlir.src and Inputs/view_oob_subview.air.mlir.src.
//
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/view_oob_cast.mlir 2>&1 | filecheck %s --check-prefix=CAST
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/view_oob_subview.mlir 2>&1 | filecheck %s --check-prefix=SUB
//
// CAST: error: @cast_past_end: air.execute: 'memref.reinterpret_cast' reaches [16] outside its source (16 elements)
// SUB: error: @subview_past_row: air.execute: 'memref.subview' reaches [0, 16] outside its source (128 elements)
