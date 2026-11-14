// C6 target model (Veir/Air/AIE_SEMANTICS.md): an aie.device after air-to-aie and airrt-to-npu,
// explored over every interleaving of locks, DMA transfers, cores and the runtime sequence.

// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough.mlir 2>/dev/null | filecheck %s --check-prefix=PASS
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough_deadlock.mlir 2>/dev/null | filecheck %s --check-prefix=DEAD
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_passthrough_race.mlir 2>/dev/null | filecheck %s --check-prefix=RACE

// PASS: @seg: 4 DMA channel(s), 1 core(s), 4 lock(s), 2 task(s)
// PASS-NEXT: no deadlock
// PASS-NEXT: 1 distinct outcome(s) of host memory
// PASS-NEXT: %arg0 = [0, 1, 2, 3, 4, 5, 6, 7, ...], %arg1 = [0, 1, 2, 3, 4, 5, 6, 7, ...]

// DEAD: DEADLOCK: the runtime sequence cannot finish
// DEAD: 0 distinct outcome(s)

// RACE: no deadlock
// RACE-NEXT: 2 distinct outcome(s) of host memory
// RACE: %arg1 = [undef, undef
