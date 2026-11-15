// The reduction on the real AIR inputs. In air_wait_async, `%e2 = air.wait_all async [%e0, %e1]`
// waits for %e0 through %e1 already, so that operand goes -- as air-dependency-canonicalize also
// drops it. The output is re-read by veir-opt (which verifies it) and checked against the input.

// RUN: air-veir reduce %S/fixture_air_wait_async.mlir.in | filecheck %s --check-prefix=WAIT
// RUN: air-veir reduce %S/fixture_air_wait_async.mlir.in > %t.wait.mlir
// RUN: veir-opt %t.wait.mlir > /dev/null
// RUN: air-veir check %S/fixture_air_wait_async.mlir.in %t.wait.mlir | filecheck %s --check-prefix=WAITOK
// RUN: air-veir graph %S/fixture_air_wait_async.mlir.in | filecheck %s --check-prefix=GRAPH
// RUN: air-veir reduce %S/fixture_air_execute.mlir.in > %t.exec.mlir
// RUN: air-veir check %S/fixture_air_execute.mlir.in %t.exec.mlir | filecheck %s --check-prefix=EXECOK
// RUN: air-veir run %S/fixture_air_execute.mlir.in | filecheck %s --check-prefix=INTERP

// WAIT:      "air.wait_all"() : () -> ()
// WAIT-NEXT: %[[W0:[^ ]+]] = "air.wait_all"() : () -> !air.async.token
// WAIT-NEXT: %[[W1:[^ ]+]] = "air.wait_all"(%[[W0]]) : (!air.async.token) -> !air.async.token
// WAIT-NEXT: "air.wait_all"(%[[W1]]) : (!air.async.token) -> !air.async.token

// WAITOK: OK @wait: 4 event(s), same reachability (6 edge(s) before, 5 after)

// GRAPH:      event 0: air.wait_all (blocking) waits for [], keeps []
// GRAPH-NEXT: event 1: air.wait_all async waits for [], keeps [], after blocking [0]
// GRAPH-NEXT: event 2: air.wait_all async waits for [1], keeps [1], after blocking [0]
// GRAPH-NEXT: event 3: air.wait_all async waits for [1, 2], keeps [2], after blocking [0]

// EXECOK: OK @air_execute_0: 5 event(s), same reachability

// INTERP: event 0 = [1 : i64], event 3 = [1 : i64], event 4 = [2 : i64, 2 : i32]
// INTERP-NEXT: race-free: every execution ends with this memory
