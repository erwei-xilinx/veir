#!/usr/bin/env python3
"""Bounded exhaustive check of air-dependency (and canonicalize) on channel programs.

Every program of up to K synchronous `air.channel.put`/`air.channel.get` on one channel `@C` is
generated:
- each endpoint moves 2 or 4 elements;
- puts read `%a` or `%x`, gets write `%x` or `%y`, so data can be got and then forwarded.

A synchronous program runs in program order with buffered transfers (D30, D35); inputs that
deadlock that way (a get before enough has been put) are skipped.

air-dependency makes every endpoint async. Its output (and canonicalize's) must then:
- not deadlock (C2);
- order same-direction endpoints (D33);
- be race-free (D6).

`air-veir races` checks all three.

  AIR_OPT=/path/to/air-opt Test/Air/bounded/check_channels.py --endpoints 4
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
KINDS = [("put", n, b) for n in (2, 4) for b in ("a", "x")] + [("get", n, b) for n in (2, 4) for b in ("x", "y")]


def sync_ok(prog):
    """Sync semantics: unbounded buffer; a get blocks until enough elements were put before it;
    every element put must be got by the end."""
    avail = 0
    for kind, n, _ in prog:
        if kind == "put":
            avail += n
        else:
            if avail < n:
                return False
            avail -= n
    return avail == 0


def describe(prog):
    return "; ".join(f"{k}{n}({b})" for k, n, b in prog)


def emit_ideal(name, prog):
    """The async program D33 asks for and no more: puts chained, gets chained, no token
    dependency between a put and a get (D30: one would deadlock a rendezvous)."""
    L = [f"  func.func @{name}(%a : memref<4xi32>, %x : memref<4xi32>, %y : memref<4xi32>) {{",
         "    %c0 = arith.constant 0 : index", "    %c1 = arith.constant 1 : index",
         "    %c2 = arith.constant 2 : index", "    %c4 = arith.constant 4 : index"]
    last = {"put": None, "get": None}
    for j, (kind, n, b) in enumerate(prog):
        dep = f" [{last[kind]}]" if last[kind] else ""
        L.append(f"    %t{j} = air.channel.{kind} async{dep} @C[] (%{b}[%c0] [%c{n}] [%c1]) : (memref<4xi32>)")
        last[kind] = f"%t{j}"
    L.append("    return")
    L.append("  }")
    return "\n".join(L)


def emit(name, prog):
    L = [f"  func.func @{name}(%a : memref<4xi32>, %x : memref<4xi32>, %y : memref<4xi32>) {{",
         "    %c0 = arith.constant 0 : index", "    %c1 = arith.constant 1 : index",
         "    %c2 = arith.constant 2 : index", "    %c4 = arith.constant 4 : index"]
    for kind, n, b in prog:
        L.append(f"    air.channel.{kind} @C[] (%{b}[%c0] [%c{n}] [%c1]) : (memref<4xi32>)")
    L.append("    return")
    L.append("  }")
    return "\n".join(L)


def summarize(text):
    """{function: (races, deadlock, D33 errors, other errors)}"""
    out, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^@(\w+): .* (\d+) race\(s\)", line)
        if m:
            cur = m.group(1)
            out[cur] = [int(m.group(2)), False, 0, 0]
            continue
        if cur is None:
            continue
        if "DEADLOCK" in line:
            out[cur][1] = True
        elif "channel order race (D33)" in line:
            out[cur][2] += 1
        elif line.strip().startswith("error:") or "internal error" in line:
            out[cur][3] += 1
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--endpoints", type=int, default=4)
    ap.add_argument("--chunk", type=int, default=300)
    ap.add_argument("--show", type=int, default=6)
    args = ap.parse_args()
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    progs = [p for k in range(2, args.endpoints + 1) for p in itertools.product(KINDS, repeat=k) if sync_ok(p)]
    stats = {key: [0, 0, 0, 0] for key in ("input", "air-dependency", "canonicalize", "D33 only")}
    examples, failures = [], []
    verdicts = {}  # (key, function) -> (races, deadlock, D33, other)
    outcomes = {}  # (key, function) -> host memory at the end (unique when race-free)
    with tempfile.TemporaryDirectory() as tmp:
        for c in range(0, len(progs), args.chunk):
            chunk = progs[c:c + args.chunk]
            src = os.path.join(tmp, "in.mlir")
            open(src, "w").write("module {\n  air.channel @C []\n" + "\n".join(
                emit(f"p{c + i}", p) for i, p in enumerate(chunk)) + "\n}\n")
            ideal = os.path.join(tmp, "ideal.mlir")
            open(ideal, "w").write("module {\n  air.channel @C []\n" + "\n".join(
                emit_ideal(f"p{c + i}", p) for i, p in enumerate(chunk)) + "\n}\n")
            for key, passes in (("input", []), ("air-dependency", ["-air-dependency"]),
                                ("canonicalize", ["-air-dependency", "-air-dependency-canonicalize"]),
                                ("D33 only", None)):
                if passes is None:
                    r = subprocess.run([air_opt, ideal] + GENERIC, capture_output=True, text=True)
                else:
                    r = subprocess.run([air_opt, src] + passes + GENERIC, capture_output=True, text=True)
                if r.returncode != 0:
                    failures.append(f"air-opt {passes}: {r.stderr[:200]}")
                    continue
                f = os.path.join(tmp, "x.mlir")
                open(f, "w").write(r.stdout)
                v = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", f], capture_output=True, text=True)
                errs = [l for l in v.stderr.splitlines() if not l.startswith("warning:")]
                if errs:
                    failures.append(f"air-veir ({key}) chunk {c}: {errs[0][:200]}")
                if key in ("input", "D33 only"):
                    oc = subprocess.run([AIR_VEIR, "outcome", "--allow-unregistered-dialect", f],
                                        capture_output=True, text=True).stdout
                    for line in oc.splitlines():
                        m = re.match(r"^@(\w+): (.*)$", line)
                        if m:
                            outcomes[(key, m.group(1))] = m.group(2)
                for fn, (races, dead, d33, other) in summarize(v.stdout).items():
                    verdicts[(key, fn)] = (races, dead, d33, other)
                    s = stats[key]
                    s[0] += races > 0
                    s[1] += dead
                    s[2] += d33 > 0
                    s[3] += other > 0
                    if key != "input" and (races or dead or d33 or other) and len(examples) < args.show:
                        examples.append(f"  {key} {fn}: {describe(progs[int(fn[1:])])}: races={races} deadlock={dead} D33={d33}")
    print(f"{len(progs)} synchronous channel program(s) of 2..{args.endpoints} endpoints (deadlock-free under sync semantics):")
    print(f"  {'':16} {'racy':>6} {'deadlock':>9} {'D33':>6} {'other':>6}")
    for key, (r, d, o, e) in stats.items():
        print(f"  {key:16} {r:6} {d:9} {o:6} {e:6}")
    # AIR-011's classes: of the programs air-dependency deadlocks, those whose minimal async form
    # (D33 only) is correct need no edge at all; the others have no correct all-async form.
    dead = [fn for (k, fn), v in verdicts.items() if k == "air-dependency" and v[1]]
    clean = [fn for fn in dead if not any(verdicts.get(("D33 only", fn), (1, True, 1, 1)))]
    same = [fn for fn in clean if outcomes.get(("D33 only", fn)) == outcomes.get(("input", fn))]
    print(f"  of {len(dead)} deadlocked by air-dependency: {len(clean)} have a D33-only async form without races or deadlock;"
          f" {len(same)} of those compute what the synchronous input computes")
    for fn in [f for f in dead if f not in same][:args.show]:
        print(f"    the D33-only form is racy, deadlocks or computes something else: {fn}: {describe(progs[int(fn[1:])])}")
    for e in examples:
        print(e)
    for f in failures[:5]:
        print("FAILURE:", f)
    bad = any(sum(stats[k]) for k in ("input", "air-dependency", "canonicalize", "D33 only")) or failures
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
