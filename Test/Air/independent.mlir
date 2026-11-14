// Three events with no dependencies stay unordered: the reduction adds no edge, every one of the
// 3! finishing orders is allowed, and a rewrite that serialises two of them is rejected for
// forbidding an order the original allows.

// RUN: air-veir reduce %S/Inputs/independent.mlir > %t.mlir
// RUN: air-veir check %S/Inputs/independent.mlir %t.mlir | filecheck %s --check-prefix=SAME
// RUN: air-veir run %S/Inputs/independent.mlir | filecheck %s --check-prefix=INTERP
// RUN: not air-veir check %S/Inputs/independent.mlir %S/Inputs/independent_serialized.mlir | filecheck %s --check-prefix=EXTRA

// SAME: OK @f: 3 event(s), same reachability (0 edge(s) before, 0 after)

// INTERP: 6 finishing order(s) allowed, 1 distinct outcome(s)

// EXTRA:     FAIL @f: the dependency graphs order the events differently
// EXTRA-NOT: the second allows
// EXTRA:     the first allows finishing order [1, 0, 2], which the second forbids
