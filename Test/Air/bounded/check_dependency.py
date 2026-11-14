#!/usr/bin/env python3
"""Bounded exhaustive check of air-dependency against SEMANTICS.md D6.

Every program of N synchronous DMAs over a 4-element L2 buffer is generated:
- each DMA copies 1 or 2 elements either from %a (L3) into %buf (L2), or from %buf into %out (L3);
- every offset into %buf that fits is used.

Each input is race-free: its DMAs are synchronous, so they run in program order (D24).
air-dependency turns the program into async DMAs with token dependencies. D6 says every pair of
DMAs that touch a common element of %buf, with at least one write, must then be ordered.
`air-veir races` checks that on air-dependency's output.

Run from the VeIR root after `lake build`:

  AIR_OPT=/path/to/air-opt Test/Air/bounded/check_dependency.py --dmas 3

Prints how many programs air-dependency leaves racy, by kind, with examples; exits 1 if any.

It also checks the model against its own theorem (`deterministic`, checklist C3): every program
`air-veir races` finds race-free must compute one outcome under every schedule (`air-veir run`).
The implementation is not proven to satisfy that theorem's framing assumption, so this checks it.
"""

import argparse
import itertools
import os
import re
import subprocess
import sys
import tempfile

AIR_VEIR = ".lake/build/bin/air-veir"
GENERIC = ["--mlir-print-op-generic", "--mlir-print-local-scope"]
N = 4  # elements in each buffer

# A DMA: (direction, offset into %buf, size). 'in' is %a -> %buf, 'out' is %buf -> %out.
DMAS = [(d, o, s) for d in ("in", "out") for s in (1, 2) for o in range(N - s + 1)]


def describe(prog):
    return "; ".join(
        f"{'a->buf' if d == 'in' else 'buf->out'}[{o}:{o + s}]" for d, o, s in prog)


def emit(name, prog):
    lines = [f"  func.func @{name}(%a : memref<{N}xi32>, %out : memref<{N}xi32>) {{"]
    lines.append("    %c0 = arith.constant 0 : index")
    lines.append("    %c1 = arith.constant 1 : index")
    lines.append("    %c2 = arith.constant 2 : index")
    lines.append("    %c3 = arith.constant 3 : index")
    lines.append(f"    %buf = memref.alloc() : memref<{N}xi32, 1>")
    for d, o, s in prog:
        if d == "in":
            lines.append(f"    air.dma_memcpy_nd (%buf[%c{o}] [%c{s}] [%c1], %a[%c0] [%c{s}] [%c1]) : "
                         f"(memref<{N}xi32, 1>, memref<{N}xi32>)")
        else:
            lines.append(f"    air.dma_memcpy_nd (%out[%c0] [%c{s}] [%c1], %buf[%c{o}] [%c{s}] [%c1]) : "
                         f"(memref<{N}xi32>, memref<{N}xi32, 1>)")
    lines.append("    return")
    lines.append("  }")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--dmas", type=int, default=2, help="DMAs per program")
    ap.add_argument("--chunk", type=int, default=300, help="functions per module")
    ap.add_argument("--show", type=int, default=8)
    args = ap.parse_args()
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    progs = list(itertools.product(DMAS, repeat=args.dmas))
    racy, kinds, examples, failures = 0, {}, [], []
    racefree_ids, nondet = set(), []
    inputs_racy = 0
    with tempfile.TemporaryDirectory() as tmp:
        for c in range(0, len(progs), args.chunk):
            chunk = progs[c:c + args.chunk]
            src = os.path.join(tmp, "in.mlir")
            with open(src, "w") as f:
                f.write("module {\n" + "\n".join(emit(f"p{c + i}", p) for i, p in enumerate(chunk)) + "\n}\n")
            # The input, in generic form, must be race-free (D24).
            gen = subprocess.run([air_opt, src] + GENERIC, capture_output=True, text=True)
            ginp = os.path.join(tmp, "in.g.mlir")
            open(ginp, "w").write(gen.stdout)
            inp = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", ginp],
                                 capture_output=True, text=True)
            inputs_racy += sum(1 for l in inp.stdout.splitlines()
                               if re.match(r"^@p\d+: .* [1-9]\d* race\(s\)", l))
            if inp.stderr.strip():
                failures.append(f"air-veir on input chunk {c}: {inp.stderr.strip()[:300]}")
            dep = os.path.join(tmp, "dep.mlir")
            r = subprocess.run([air_opt, src, "-air-dependency"] + GENERIC, capture_output=True, text=True)
            if r.returncode != 0:
                failures.append(f"air-dependency failed on chunk {c}: {r.stderr[:300]}")
                continue
            open(dep, "w").write(r.stdout)
            out = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", dep],
                                 capture_output=True, text=True)
            if out.stderr.strip():
                failures.append(f"air-veir on chunk {c}: {out.stderr.strip()[:300]}")
            cur = None
            for line in out.stdout.splitlines():
                m = re.match(r"^@p(\d+): .* (\d+) race\(s\), (\d+) problem", line)
                if m:
                    cur = int(m.group(1))
                    if int(m.group(2)) > 0:
                        racy += 1
                    elif int(m.group(3)) == 0:
                        racefree_ids.add(cur)
                    continue
                m = re.match(r"^\s+race: (\w+) on (.+?) element", line)
                if m and cur is not None:
                    key = f"{m.group(1)} on {'%buf (L2)' if 'alloc' in m.group(2) else m.group(2)}"
                    kinds[key] = kinds.get(key, 0) + 1
                    if len(examples) < args.show:
                        examples.append(f"  p{cur}: {describe(progs[cur])}\n    {line.strip()}")
            # C3: race-free programs compute one outcome under every schedule.
            run = subprocess.run([AIR_VEIR, "run", "--allow-unregistered-dialect", dep],
                                 capture_output=True, text=True)
            cur = None
            for line in run.stdout.splitlines():
                m = re.match(r"^@p(\d+): program order", line)
                if m:
                    cur = int(m.group(1))
                    continue
                m = re.match(r"^\s+\d+ finishing order\(s\) allowed.*?(\d+) distinct outcome", line)
                if m and cur in racefree_ids and int(m.group(1)) != 1:
                    nondet.append(cur)
    print(f"{len(progs)} program(s) of {args.dmas} DMA(s): {inputs_racy} racy before air-dependency, "
          f"{racy} racy after it")
    print(f"C3: {len(racefree_ids)} race-free program(s), {len(nondet)} with more than one outcome"
          + (f" (e.g. p{nondet[0]})" if nondet else ""))
    if nondet:
        failures.append(f"race-free but nondeterministic: {nondet[:5]}")
    for k, n in sorted(kinds.items(), key=lambda kv: -kv[1]):
        print(f"  {n:6} {k}")
    for e in examples:
        print(e)
    for f in failures:
        print("FAILURE:", f)
    sys.exit(1 if racy or failures else 0)


if __name__ == "__main__":
    main()
