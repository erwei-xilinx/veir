// A blocking air.wait_all (no result) holds the host until its dependencies are done, so
// everything issued after it waits for it although no operand says so. Here C reads A's result
// with no token for A: it is ordered after A through the wait alone, so this is not a race. C's
// explicit dependency on A is then redundant -- A -> wait -> C -- and is dropped; the implicit
// edge, which is not an operand, stays.

// RUN: air-veir graph %s | filecheck %s --check-prefix=GRAPH
// RUN: air-veir run %s | filecheck %s --check-prefix=INTERP
// RUN: air-veir reduce %s > %t.mlir
// RUN: filecheck %s --check-prefix=REDUCE < %t.mlir
// RUN: air-veir check %s %t.mlir | filecheck %s --check-prefix=SAME

// GRAPH:      event 0: air.execute waits for [], keeps []
// GRAPH-NEXT: event 1: air.wait_all (blocking) waits for [0], keeps [0]
// GRAPH-NEXT: event 2: air.execute waits for [], keeps [], after blocking [1], reads results of [0]
// GRAPH-NEXT: event 3: air.execute waits for [0], keeps [], after blocking [1], reads results of [0]
// GRAPH-NOT:  warning

// INTERP:      program order: event 0 = [5 : i32], event 2 = [10 : i32], event 3 = [25 : i32]
// INTERP-NEXT: 2 finishing order(s) allowed, 1 distinct outcome(s)

// REDUCE:      "air.wait_all"(%{{.*}}#0) : (!air.async.token) -> ()
// REDUCE:      "air.execute"() ({
// REDUCE:      "air.execute"() ({

// SAME: OK @f: 4 event(s), same reachability (4 edge(s) before, 3 after)

"builtin.module"() ({
  "func.func"() <{function_type = () -> (), sym_name = "f"}> ({
    %a:2 = "air.execute"() ({
      %c5 = "arith.constant"() <{value = 5 : i32}> : () -> i32
      "air.execute_terminator"(%c5) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    "air.wait_all"(%a#0) : (!air.async.token) -> ()
    %b:2 = "air.execute"() ({
      %x = "arith.addi"(%a#1, %a#1) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
      "air.execute_terminator"(%x) : (i32) -> ()
    }) : () -> (!air.async.token, i32)
    %c:2 = "air.execute"(%a#0) ({
      %y = "arith.muli"(%a#1, %a#1) <{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32
      "air.execute_terminator"(%y) : (i32) -> ()
    }) : (!air.async.token) -> (!air.async.token, i32)
    "func.return"() : () -> ()
  }) : () -> ()
}) : () -> ()
