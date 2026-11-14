// C6 target model (Veir/Air/AIE_SEMANTICS.md): an aie.device after air-to-aie and airrt-to-npu,
// explored over every interleaving of locks, DMA transfers, cores and the runtime sequence.

// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough.mlir 2>/dev/null | filecheck %s --check-prefix=PASS
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough_deadlock.mlir 2>/dev/null | filecheck %s --check-prefix=DEAD
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough_race.mlir 2>/dev/null | filecheck %s --check-prefix=RACE

// PASS: @seg: 4 DMA channel(s), 1 core(s), 4 lock(s), 2 task(s)
// PASS-NEXT: no deadlock
// PASS-NEXT: 1 distinct outcome(s) of host memory
// PASS-NEXT: %arg0 = [0..63], %arg1 = [0..63]

// DEAD: DEADLOCK: the runtime sequence cannot finish
// DEAD: 0 distinct outcome(s)

// RACE: no deadlock
// RACE-NEXT: 2 distinct outcome(s) of host memory
// RACE: %arg1 = [undef x 64]

// Through an L2 memtile: correct.
// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_l2.mlir 2>/dev/null | filecheck %s --check-prefix=L2
// L2: no deadlock
// L2-NEXT: 1 distinct outcome(s) of host memory
// L2-NEXT: %arg0 = [0..63], %arg1 = [0..63]

// AIR-022: an in-place relay in a loop. The AIR input is deterministic; the lowered design is not.
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_inplace_relay.mlir 2>/dev/null | filecheck %s --check-prefix=RELAY
// RELAY: no deadlock
// RELAY-NEXT: 4 distinct outcome(s) of host memory
// RELAY-DAG: %arg1 = [0..63]
// RELAY-DAG: %arg1 = [32..63, 32..63]
