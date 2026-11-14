#!/usr/bin/env python3
"""Bounded exhaustive check of air-dependency and air-dependency-canonicalize on loops.

Every program of this shape is generated:

  %buf = memref.alloc() : memref<4xi32, 1>
  scf.for %i = 0 to T step 1 {
    <K synchronous DMAs between %a / %out (L3) and %buf (L2)>
  }

Each DMA copies 1 or 2 elements into or out of %buf, at a constant offset or at offset %i.
Each input is race-free: its DMAs are synchronous and run in program order (D24, D26).

Then:
1. air-dependency must produce a race-free program (D6). `air-veir races` checks this on the
   instantiated loop.
2. air-dependency-canonicalize, run on that output, must order the events identically.
   `air-veir check` compares the two instantiated event graphs.

  AIR_OPT=/path/to/air-opt Test/Air/bounded/check_loops.py --trips 2 --dmas 2
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
N = 4


def dma_kinds(trips):
    """(direction, offset, size, follows %i)."""
    out = []
    for d in ("in", "out"):
        for s in (1, 2):
            for o in range(N - s + 1):
                out.append((d, o, s, False))
            for o in range(N - s - (trips - 1) + 1):
                out.append((d, o, s, True))
    return out


def describe(prog):
    return "; ".join(f"{'a->buf' if d == 'in' else 'buf->out'}[{'%i+' if iv else ''}{o}:+{s}]"
                     for d, o, s, iv in prog)


def emit(name, trips, prog):
    L = [f"  func.func @{name}(%a : memref<{N}xi32>, %out : memref<{N}xi32>) {{"]
    L += [f"    %c{k} = arith.constant {k} : index" for k in range(5)]
    L.append(f"    %buf = memref.alloc() : memref<{N}xi32, 1>")
    L.append(f"    scf.for %i = %c0 to %c{trips} step %c1 {{")
    for j, (d, o, s, iv) in enumerate(prog):
        if iv:
            L.append(f"      %o{j} = arith.addi %i, %c{o} : index")
            off = f"%o{j}"
        else:
            off = f"%c{o}"
        if d == "in":
            L.append(f"      air.dma_memcpy_nd (%buf[{off}] [%c{s}] [%c1], %a[%c0] [%c{s}] [%c1]) : "
                     f"(memref<{N}xi32, 1>, memref<{N}xi32>)")
        else:
            L.append(f"      air.dma_memcpy_nd (%out[%c0] [%c{s}] [%c1], %buf[{off}] [%c{s}] [%c1]) : "
                     f"(memref<{N}xi32>, memref<{N}xi32, 1>)")
    L.append("    }")
    L.append("    return")
    L.append("  }")
    return "\n".join(L)


def per_func(text):
    funcs, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^(?:OK |FAIL )?@(\w+)", line)
        if m:
            cur = m.group(1)
            funcs.setdefault(cur, []).append(line)
        elif cur is not None:
            funcs[cur].append(line)
    return funcs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--trips", type=int, default=2)
    ap.add_argument("--dmas", type=int, default=2)
    ap.add_argument("--chunk", type=int, default=200)
    ap.add_argument("--show", type=int, default=6)
    args = ap.parse_args()
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    progs = list(itertools.product(dma_kinds(args.trips), repeat=args.dmas))
    stats = {"input racy": 0, "dependency racy": 0, "canonicalize reorders": 0, "canonicalize racy": 0}
    examples, failures = [], []
    with tempfile.TemporaryDirectory() as tmp:
        for c in range(0, len(progs), args.chunk):
            chunk = progs[c:c + args.chunk]
            src = os.path.join(tmp, "in.mlir")
            open(src, "w").write("module {\n" + "\n".join(
                emit(f"p{c + i}", args.trips, p) for i, p in enumerate(chunk)) + "\n}\n")
            files = {}
            for key, passes in (("in", []), ("dep", ["-air-dependency"]),
                                ("canon", ["-air-dependency", "-air-dependency-canonicalize"])):
                r = subprocess.run([air_opt, src] + passes + GENERIC, capture_output=True, text=True)
                if r.returncode != 0:
                    failures.append(f"air-opt {passes} failed on chunk {c}: {r.stderr[:200]}")
                files[key] = os.path.join(tmp, f"{key}.mlir")
                open(files[key], "w").write(r.stdout)
            for key, stat in (("in", "input racy"), ("dep", "dependency racy"), ("canon", "canonicalize racy")):
                r = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", files[key]],
                                   capture_output=True, text=True)
                errs = [l for l in r.stderr.splitlines() if not l.startswith("warning:")]
                if errs:
                    failures.append(f"air-veir races ({key}) on chunk {c}: {errs[0][:200]}")
                for f, ls in per_func(r.stdout).items():
                    if re.search(r" [1-9]\d* race\(s\)", ls[0]):
                        stats[stat] += 1
                        if key != "in" and len(examples) < args.show:
                            examples.append(f"  {key} {f}: {describe(progs[int(f[1:])])}\n    {ls[1].strip() if len(ls) > 1 else ''}")
            r = subprocess.run([AIR_VEIR, "check", "--allow-unregistered-dialect", files["dep"], files["canon"]],
                               capture_output=True, text=True)
            errs = [l for l in r.stderr.splitlines() if not l.startswith("warning:")]
            if errs:
                failures.append(f"air-veir check on chunk {c}: {errs[0][:200]}")
            for f, ls in per_func(r.stdout).items():
                if ls[0].startswith("FAIL"):
                    stats["canonicalize reorders"] += 1
                    if len(examples) < args.show:
                        examples.append(f"  canonicalize {f}: {describe(progs[int(f[1:])])}\n    " + " | ".join(l.strip() for l in ls[:2]))
    print(f"{len(progs)} loop program(s), {args.trips} trip(s), {args.dmas} DMA(s) per iteration:")
    for k, n in stats.items():
        print(f"  {k}: {n}")
    for e in examples:
        print(e)
    for f in failures[:5]:
        print("FAILURE:", f)
    sys.exit(1 if failures or stats["input racy"] or stats["dependency racy"] or stats["canonicalize reorders"] else 0)


if __name__ == "__main__":
    main()
