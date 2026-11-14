// A -> B -> C and A -> C. The edge A -> C is implied by the path through B, so the reduction
// drops it, and the program still has exactly one finishing order and the same values.

// RUN: air-veir graph %s | filecheck %s --check-prefix=GRAPH
// RUN: air-veir reduce %s | filecheck %s --check-prefix=REDUCE
// RUN: air-veir reduce %s > %t.mlir
// RUN: air-veir check %s %t.mlir | filecheck %s --check-prefix=CHECK-OK
// RUN: air-veir run %s | filecheck %s --check-prefix=INTERP
// RUN: air-veir run %t.mlir | filecheck %s --check-prefix=INTERP

// GRAPH:      event 0: air.execute waits for [], keeps []
// GRAPH-NEXT: event 1: air.execute waits for [0], keeps [0], reads results of [0]
// GRAPH-NEXT: event 2: air.execute waits for [0, 1], keeps [1], reads results of [0, 1]
// GRAPH-NOT:  warning

// REDUCE:     %[[A:[^ ]+]]:2 = "air.execute"() ({
// REDUCE:     %[[B:[^ ]+]]:2 = "air.execute"(%[[A]]#0) ({
// REDUCE:     "air.execute"(%[[B]]#0) ({

// CHECK-OK: OK @f: 3 event(s), same reachability (3 edge(s) before, 2 after)

// INTERP:      program order: event 0 = [1 : i32], event 1 = [2 : i32], event 2 = [3 : i32]
// INTERP-NEXT: 1 finishing order(s) allowed, 1 distinct outcome(s)

"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a:2 = "air.execute"() ({
      %c1 = "arith.constant"() <{value = 1 : i32}> : () -> i32
      "air.execute_terminator"(%c1) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    %b:2 = "air.execute"(%a#0) ({
      %x = "arith.addi"(%a#1, %a#1) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
      "air.execute_terminator"(%x) : (i32) -> ()
    }) : (!air.async.token) -> (!air.async.token, i32)
    %c:2 = "air.execute"(%a#0, %b#0) ({
      %y = "arith.addi"(%a#1, %b#1) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
      "air.execute_terminator"(%y) : (i32) -> ()
    }) : (!air.async.token, !air.async.token) -> (!air.async.token, i32)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
