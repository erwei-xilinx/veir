// Layer 4: channels (SEMANTICS.md D28-D36, D51). Verdicts come from the proven channel model:
// Veir.Air.ChanSem (semantics, deadlock), ChanMem (races, determinism), ChanFast (the checks).

// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/layer4_channels.mlir | filecheck %s --check-prefix=RACES
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/layer4_channels.mlir | filecheck %s --check-prefix=INTERP

// RACES-LABEL: @rendezvous:
// RACES-NEXT:  no deadlock (proven, Chan.checkH_true)
// RACES-LABEL: @rendezvous_deadlock:
// RACES-NEXT:  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: event 0 (air.channel.put), event 1 (air.channel.get)
// RACES-LABEL: @sync_put_then_get:
// RACES-NEXT:  no deadlock
// RACES-LABEL: @sync_get_then_put:
// RACES-NEXT:  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: event 0 (air.channel.get (sync)), event 1 (air.channel.put (sync))
// RACES-LABEL: @stream_split:
// RACES-NEXT:  no deadlock
// RACES-LABEL: @order_race:
// RACES-NEXT:  error: channel order race (D33): two puts on @C[] (events 0 and 1) with no token path between them
// Broadcast is not in the proven model yet (README, open work).
// RACES-LABEL: @broadcast:
// RACES-NEXT:  error: not covered: event 0: a put feeding 2 subchannels (broadcast)
// RACES-LABEL: @broadcast_missing:
// RACES-NEXT:  error: not covered: event 0: a put feeding 2 subchannels (broadcast)
// RACES-LABEL: @starved_get:
// RACES-NEXT:  DEADLOCK (proven, Chan.checkH_false): no execution completes; these events never finish: event 1 (air.channel.get)
// RACES-LABEL: @padding:
// RACES-NEXT:  no deadlock

// INTERP-LABEL: @rendezvous: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
// INTERP-LABEL: @rendezvous_deadlock: deadlocks
// INTERP-LABEL: @stream_split: {{.*}}%arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg2 = [4 : i32, 5 : i32, 6 : i32, 7 : i32]
// INTERP-LABEL: @order_race: not covered
// INTERP-LABEL: @broadcast: not covered
// INTERP-LABEL: @padding: %arg0 = [0 : i32, 1 : i32], %arg1 = [0 : i32, 0 : i32, 0 : i32, 1 : i32, 0 : i32]

// Decision D50 -- on a [1, 1] channel, @C[] is subchannel [0, 0].
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/d50_implicit_index.mlir 2>/dev/null | filecheck %s --check-prefix=D50
// D50: @implicit_index: %arg0 = [0 : i32, 1 : i32, 2 : i32, 3 : i32], %arg1 = [0 : i32, 1 : i32, 2 : i32, 3 : i32]
