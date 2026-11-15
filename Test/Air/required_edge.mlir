// A -> C is the only constraint, and C reads A's result. The reduction must keep it. Removing it
// by hand is caught three ways: the checker rejects the rewrite and names a finishing order the
// original forbids; the graph reports an unordered read; and running every allowed order of the
// broken program shows the read can happen before A has produced its value.

// RUN: air-veir graph %S/Inputs/required_edge.mlir | filecheck %s --check-prefix=GRAPH
// RUN: air-veir reduce %S/Inputs/required_edge.mlir > %t.mlir
// RUN: air-veir check %S/Inputs/required_edge.mlir %t.mlir | filecheck %s --check-prefix=KEPT
// RUN: air-veir run %S/Inputs/required_edge.mlir | filecheck %s --check-prefix=GOOD
// RUN: not air-veir check %S/Inputs/required_edge.mlir %S/Inputs/required_edge_dropped.mlir | filecheck %s --check-prefix=REJECT
// RUN: air-veir graph %S/Inputs/required_edge_dropped.mlir | filecheck %s --check-prefix=RACE
// RUN: air-veir run %S/Inputs/required_edge_dropped.mlir | filecheck %s --check-prefix=BAD

// GRAPH: event 2: air.execute waits for [0], keeps [0], reads results of [0]

// KEPT: OK @f: 3 event(s), same reachability (1 edge(s) before, 1 after)

// GOOD:      @f: event 0 = [1 : i32], event 1 = [10 : i32], event 2 = [2 : i32]
// GOOD-NEXT: race-free: every execution ends with this memory

// REJECT:      FAIL @f: the dependency graphs order the events differently
// REJECT-NEXT: the second allows finishing order [1, 2, 0], which the first forbids
// REJECT-NEXT: running that order: fault: event 2: 'arith.addi' read a result of event 0 before it was available
// REJECT-NOT:  the first allows

// RACE: warning: event 2 reads a result of event 0 without waiting for it

// D4: the read of event 0's result is unordered, a race on its results; two checked executions
// end differently.
// BAD-DAG:  fault: event 2: 'arith.addi' read a result of event 0 before it was available
// BAD-DAG:  ends differently: event 0 = [1 : i32], event 1 = [10 : i32], event 2 = [2 : i32]
