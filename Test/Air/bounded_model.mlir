// Bounded exhaustive check of the model, without air-opt: every one of the 2295 programs of four
// events (bounded/gen.py) is reduced, and every reduction is accepted by the checker. The checks
// against AIR's own pass are in bounded/check.py, which needs air-opt.

// RUN: python3 %S/bounded/gen.py --events 4 > %t.mlir
// RUN: air-veir reduce %t.mlir > %t.red.mlir
// RUN: veir-opt %t.red.mlir > /dev/null
// RUN: air-veir check %t.mlir %t.red.mlir > %t.check.txt
// RUN: grep -c '^OK' %t.check.txt | filecheck %s --check-prefix=COUNT
// RUN: not grep FAIL %t.check.txt
// RUN: python3 %S/bounded/gen.py --events 3 --data > %t.data.mlir
// RUN: air-veir run %t.data.mlir | grep -c 'finishing order' | filecheck %s --check-prefix=DATA

// COUNT: 2295
// DATA: 229
