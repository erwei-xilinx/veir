// The AIE model on cores that read a buffer through a load stream (aievec.fifo_start makes a
// pointer from the buffer; the pops in an scf.for with iteration arguments load through it).
// Pointer provenance: an op using a value derived from a buffer (the pointer, an address computed
// from it, a stack slot it was stored to, an integer address) reads and writes that buffer when it
// runs (D22). A race: in a reachable state, two agents' next steps touch one buffer, one writing.
//
// The inputs are air-to-aie outputs of mlir-air's air_channel_release_ring_stream*.mlir and
// air_channel_release_stream_if.mlir tests (the core's buffer is filled twice), from mlir-air
// a2efbd21c ("early", the release right after the acquire) and from PR #2457 ("late"), plus
// variants of the late one with the release moved.
//
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_release_early.mlir 2>/dev/null | filecheck %s --check-prefix=EARLY
// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_release_late.mlir 2>/dev/null | filecheck %s --check-prefix=LATE
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_slot_early.mlir 2>/dev/null | filecheck %s --check-prefix=EARLY
// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_slot_late.mlir 2>/dev/null | filecheck %s --check-prefix=LATE
// RUN: air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_if.mlir 2>/dev/null | filecheck %s --check-prefix=LATE
//
// The release between fifo_start and the pops: only the pops, through the pointer, read the buffer
// after it.
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_release_mid.mlir 2>/dev/null | filecheck %s --check-prefix=EARLY
// The release before a load through an integer address of the buffer (extract_aligned_pointer,
// index_cast, inttoptr).
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_int_address.mlir 2>/dev/null | filecheck %s --check-prefix=EARLY
// A pointer stored to memory that is not a stack slot: its uses are not tracked, refused.
// RUN: not air-veir aie --allow-unregistered-dialect %S/Inputs/aie_stream_store_escape.mlir 2>/dev/null | filecheck %s --check-prefix=ESCAPE
//
// EARLY: proven (AieCert.Cert.exact)
// EARLY: RACE: in a reachable state (AieCert.Cert.parents_sound), 'tile (2, 3) MM2S 0 -> tile (2, 4) S2MM 0: 576 element(s)' and 'core (2, 4): compute' can each happen next and both touch buf1, one writing
// LATE: proven (AieCert.Cert.exact)
// LATE: no deadlock
// LATE: no race: no reachable state has two agents' next steps touching one buffer, one writing
// ESCAPE: refused: core: a pointer into a buffer is stored to memory that is not a stack slot (llvm.alloca); its uses are not tracked
