// Layer 4: channels (SEMANTICS.md D28-D35). Every deadlock verdict carries a stuck set checked by
// stuckB, every no-deadlock verdict a schedule checked by scheduleB (Veir.Air.Schedule).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer4_channels.mlir | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer4_channels.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @rendezvous:
// RACES-NEXT:  no deadlock: a schedule exists (checked by scheduleB)
// RACES-LABEL: @rendezvous_deadlock:
// RACES-NEXT:  DEADLOCK: no schedule exists; stuck (checked by stuckB): finish of event 0 (air.channel.put), start of event 1 (air.channel.get), finish of event 1 (air.channel.get)
// RACES-LABEL: @sync_put_then_get:
// RACES-NEXT:  no deadlock
// RACES-LABEL: @sync_get_then_put:
// RACES-NEXT:  DEADLOCK: no schedule exists; stuck (checked by stuckB): finish of event 0 (air.channel.get (sync)), start of event 1 (air.channel.put (sync)), finish of event 1 (air.channel.put (sync))
// RACES-LABEL: @stream_split:
// RACES-NEXT:  no deadlock
// RACES-LABEL: @order_race:
// RACES-NEXT:  error: channel order race (D33): two puts on @C[] (events 0 and 1) with no token path between them
// RACES-LABEL: @broadcast:
// RACES-NEXT:  no deadlock
// RACES-LABEL: @broadcast_missing:
// RACES-NEXT:  error: @B[0, 1]: event 0's async put has 4 element(s) no get takes: it can never complete (D34)
// RACES-NEXT:  DEADLOCK: no schedule exists; stuck (checked by stuckB): finish of event 0 (air.channel.put)
// RACES-LABEL: @starved_get:
// RACES-NEXT:  error: @C[]: event 1's get waits for 4 element(s) no put provides
// RACES-NEXT:  DEADLOCK
// RACES-LABEL: @padding:
// RACES-NEXT:  no deadlock

// INTERP-LABEL: @rendezvous: a schedule: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-LABEL: @rendezvous_deadlock: deadlocks
// INTERP-LABEL: @stream_split: a schedule: {{.*}}%arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg2 = [4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-LABEL: @broadcast: a schedule: {{.*}}%arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg2 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-NEXT:  44 start/finish order(s) allowed, 1 distinct outcome(s)
// INTERP-LABEL: @padding: a schedule: %arg0 = [0 : i32, 1 : i32], %arg1 = [0 : i32, 0 : i32, 0 : i32, 1 : i32, 0 : i32]

// Decision D50 -- on a [1, 1] channel, @C[] is subchannel [0, 0].
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/d50_implicit_index.mlir 2>/dev/null | filecheck %s --check-prefix=D50
// D50: @implicit_index: a schedule: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
