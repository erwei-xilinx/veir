// RUN: VEIR_ROUNDTRIP
// RUN: MLIR_UNREGISTERED_ROUNDTRIP

// The elements of an i1 dense array are `true` and `false`, as MLIR prints them.

"builtin.module"() ({
    "test.test"() { bools = array<i1: false, true, false>, empty = array<i1>, ints = array<i32: 1, -2> } : () -> ()
    // CHECK: "test.test"() {"bools" = array<i1: false, true, false>, "empty" = array<i1>, "ints" = array<i32: 1, -2>} : () -> ()
}) : () -> ()
