// Decision D54: air.channel.issue starts the transfer of the channel op tagged with its issue_id;
// no element moves before the issue runs, and its offset (in elements) is read when it runs.

// RUN: air-veir races --allow-unregistered-dialect %S/Inputs/d54_issue.mlir 2>/dev/null | filecheck %s
// RUN: air-veir run --allow-unregistered-dialect %S/Inputs/d54_issue.mlir 2>/dev/null | filecheck %s --check-prefix=INTERP
// RUN: not air-veir races --allow-unregistered-dialect %S/Inputs/d54_mismatch.mlir 2>&1 | filecheck %s --check-prefix=COUNT

// CHECK-LABEL: @core_issue:
// CHECK-NEXT:  no deadlock (proven, Chan.checkH_true)

// The core loads 2 and issues offset 2 * 4: the get receives src[8..12).
// INTERP: @core_issue: {{.*}}%arg1 = [8 : i32, 9 : i32, 10 : i32, 11 : i32]
// INTERP-NEXT: race-free

// Two tiles issue for one transfer (D54.5).
// COUNT: issue_id 0: 2 air.channel.issue(s) for 1 transfer(s) tagged air.device_issue in one launch instance (D54)

// Decision D58: air.device_issue_count = 2 is two transfers in order, each shifted by its issue's
// offset (0, then 8).
// RUN: air-veir outcome --allow-unregistered-dialect %S/Inputs/d58_count.mlir 2>/dev/null | filecheck %s --check-prefix=COUNTED
// COUNTED: @counted: %arg0 = [0..15], %arg1 = [0..3, 8..11]
