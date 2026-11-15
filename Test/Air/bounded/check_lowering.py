#!/usr/bin/env python3
"""C6 phase 2: translation-validate AIR's lowering (aircc) on small data-movement programs.

Every program moves N elements from the host through a herd (and optionally an L2 buffer in the
segment, or a broadcast to two tiles) and back, in K chunks. The herd relays each chunk in place
(a get into a buffer, then a put from it) or through a copy into a second buffer. For each
program:

1. VeIR's AIR model must find the input race-free and deadlock-free (`air-veir races`). Its one
   outcome (`deterministic`, C3) is `air-veir outcome`.
2. `aircc --output-format=none` lowers it; the `npu.*.mlir` it leaves is the AIE design.
3. VeIR's AIE model (`air-veir aie`, AIE_SEMANTICS.md) explores every interleaving of the design.
   It must not deadlock, and its only outcome must be the AIR outcome.

A design with more outcomes is nondeterministic where the program is not. A design whose one
outcome differs is wrong. Either is a lowering bug, given T1-T5.

Channel endpoints name their subchannel explicitly (`@C[%c0, %c0]`): whether `@C[]` means the
same is an open question (D50).

  AIR_OPT=... AIRCC=... Test/Air/bounded/check_lowering.py [--only NAME]
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
N = 32


def program(path, k, hoist, tiles, body="inplace"):
    """An AIR program in custom syntax.

    `body`: the herd relays each chunk in place (`inplace`: get into %a, put %a) or through a
    copy (`copy`: get into %a, memref.copy to %b, put %b). `path = "bcast"`: one put on a
    broadcast channel feeds both tiles; tile t returns its copy to the t-th half of a 2N output."""
    bcast = path == "bcast"
    c = N // k // (1 if bcast else tiles)  # elements per chunk per tile
    per = 0 if bcast else N // tiles      # input elements per tile
    NO = 2 * N if bcast else N
    L = ["module {"]
    if bcast:
        L.append(f"  air.channel @In [1, 1] {{broadcast_shape = [{tiles}, 1]}}")
        L.append(f"  air.channel @Out [{tiles}, 1]")
    else:
        for ch in ["In", "Out"] + (["ToL1", "FromL1"] if path == "l2" else []):
            L.append(f"  air.channel @{ch} [{tiles}, 1]")
    L.append(f"  func.func @f(%in: memref<{N}xi32>, %out: memref<{NO}xi32>) {{")
    L.append("    %c1 = arith.constant 1 : index")
    L.append(f"    air.launch (%lx) in (%ls=%c1) args(%ain=%in, %aout=%out) : memref<{N}xi32>, memref<{NO}xi32> {{")
    L += ["      %c0 = arith.constant 0 : index", "      %u1 = arith.constant 1 : index",
          f"      %ck = arith.constant {k} : index", f"      %cc = arith.constant {c} : index",
          f"      %cp = arith.constant {N if bcast else per} : index"]
    for t in range(tiles):
        L.append(f"      %t{t} = arith.constant {t} : index")

    def host(op, ch, buf):
        for t in range(1 if (bcast and op == "put") else tiles):
            L.append(f"      scf.for %i{op}{t} = %c0 to %ck step %u1 {{")
            L.append(f"        %b{op}{t} = arith.muli %t{t}, %cp : index")
            L.append(f"        %m{op}{t} = arith.muli %i{op}{t}, %cc : index")
            L.append(f"        %o{op}{t} = arith.addi %b{op}{t}, %m{op}{t} : index")
            if bcast and op == "put":
                L.append(f"        air.channel.put @{ch}[%c0, %c0] (%{buf}[%m{op}{t}] [%cc] [%u1]) : (memref<{N}xi32>)")
            else:
                ty = NO if op == "get" else N
                L.append(f"        air.channel.{op} @{ch}[%t{t}, %c0] (%{buf}[%o{op}{t}] [%cc] [%u1]) : (memref<{ty}xi32>)")
            L.append("      }")

    def l2relay(src, dst):
        for t in range(tiles):
            if hoist:
                L.append(f"        %l2{src}{t} = memref.alloc() : memref<{c}xi32, 1>")
            L.append(f"        scf.for %j{src}{t} = %s0 to %sk step %s1 {{")
            if not hoist:
                L.append(f"          %l2{src}{t} = memref.alloc() : memref<{c}xi32, 1>")
            L.append(f"          air.channel.get @{src}[%st{t}, %s0] (%l2{src}{t}[] [] []) : (memref<{c}xi32, 1>)")
            L.append(f"          air.channel.put @{dst}[%st{t}, %s0] (%l2{src}{t}[] [] []) : (memref<{c}xi32, 1>)")
            if not hoist:
                L.append(f"          memref.dealloc %l2{src}{t} : memref<{c}xi32, 1>")
            L.append("        }")
            if hoist:
                L.append(f"        memref.dealloc %l2{src}{t} : memref<{c}xi32, 1>")
    host("put", "In", "ain")
    L.append("      air.segment @seg {")
    L += ["        %s0 = arith.constant 0 : index", "        %s1 = arith.constant 1 : index",
          f"        %sk = arith.constant {k} : index", f"        %stiles = arith.constant {tiles} : index"]
    if path == "l2":
        # The segment relays each chunk of each tile through L2, in place: to L1 before the herd,
        # back from L1 after it. (A synchronous get placed before the herd that feeds it would
        # wait forever, D35, D48.)
        for t in range(tiles):
            L.append(f"        %st{t} = arith.constant {t} : index")
        l2relay("In", "ToL1")
    hin, hout = ("ToL1", "FromL1") if path == "l2" else ("In", "Out")
    L.append(f"        air.herd @h tile (%x, %y) in (%sx=%stiles, %sy=%s1) {{")
    L += ["          %h0 = arith.constant 0 : index", "          %h1 = arith.constant 1 : index",
          f"          %hk = arith.constant {k} : index"]
    bufs = ["%a", "%b"] if body == "copy" else ["%a"]
    if hoist:
        for b in bufs:
            L.append(f"          {b} = memref.alloc() : memref<{c}xi32, 2>")
    L.append("          scf.for %j = %h0 to %hk step %h1 {")
    if not hoist:
        for b in bufs:
            L.append(f"            {b} = memref.alloc() : memref<{c}xi32, 2>")
    L.append(f"            air.channel.get @{hin}[%x, %y] (%a[] [] []) : (memref<{c}xi32, 2>)")
    if body == "copy":
        L.append(f"            memref.copy %a, %b : memref<{c}xi32, 2> to memref<{c}xi32, 2>")
    L.append(f"            air.channel.put @{hout}[%x, %y] ({bufs[-1]}[] [] []) : (memref<{c}xi32, 2>)")
    if not hoist:
        for b in bufs:
            L.append(f"            memref.dealloc {b} : memref<{c}xi32, 2>")
    L.append("          }")
    if hoist:
        for b in bufs:
            L.append(f"          memref.dealloc {b} : memref<{c}xi32, 2>")
    L.append("        }")
    if path == "l2":
        l2relay("FromL1", "Out")
    L.append("      }")
    host("get", "Out", "aout")
    L += ["    }", "    return", "  }", "}"]
    return "\n".join(L) + "\n"


def run(cmd, timeout=900):
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only")
    ap.add_argument("--keep", help="directory to keep every program and design in")
    ap.add_argument("--max-states", type=int, default=200000)
    ap.add_argument("--compare-por", action="store_true",
                    help="also explore without partial-order reduction; where that completes, the two verdicts must agree")
    args = ap.parse_args()
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT")
    aircc = os.environ.get("AIRCC") or sys.exit("set AIRCC")
    tmp = args.keep or tempfile.mkdtemp(prefix="check_lowering.")
    os.makedirs(tmp, exist_ok=True)
    stats = {}
    cases = [(p, k, h, t, b) for p, k, h, t, b in
             itertools.product(["direct", "l2", "bcast"], [1, 2, 4], [False, True], [1, 2], ["inplace", "copy"])
             if not (p == "bcast" and t == 1)]
    for path, k, hoist, tiles, body in cases:
        name = f"{path}_k{k}_{'hoist' if hoist else 'inner'}_t{tiles}_{body}"
        if args.only and args.only != name:
            continue
        d = os.path.join(tmp, name)
        os.makedirs(d, exist_ok=True)
        src = os.path.join(d, "in.mlir")
        open(src, "w").write(program(path, k, hoist, tiles, body))
        g = os.path.join(d, "in.generic.mlir")
        r = run([air_opt, src] + GENERIC)
        if r.returncode:
            verdict = f"input rejected by air-opt: {r.stderr.strip()[:120]}"
        else:
            open(g, "w").write(r.stdout)
            races = run([AIR_VEIR, "races", "--allow-unregistered-dialect", g])
            if races.returncode:
                verdict = "input not race-free in the AIR model (skipped)"
            else:
                air = run([AIR_VEIR, "outcome", "--allow-unregistered-dialect", g]).stdout.strip()
                air_out = air.split(": ", 1)[1] if ": " in air else air
                lr = run([aircc, src, "--device=npu2", "--output-format=none", f"--tmpdir={d}/t", "-o", f"{d}/out"])
                npu = [f for f in os.listdir(f"{d}/t")] if os.path.isdir(f"{d}/t") else []
                npu = [f for f in npu if f.startswith("npu.") and f.endswith(".mlir")]
                if lr.returncode or not npu:
                    verdict = f"aircc failed: {(lr.stderr or lr.stdout).strip().splitlines()[-1][:120] if (lr.stderr or lr.stdout).strip() else '?'}"
                else:
                    ag = os.path.join(d, "aie.generic.mlir")
                    open(ag, "w").write(run([air_opt, f"{d}/t/{npu[0]}"] + GENERIC).stdout)
                    aie = run([AIR_VEIR, "aie", "--allow-unregistered-dialect", "--all-outcomes", f"--max-states={args.max_states}", ag]).stdout
                    if args.compare_por:
                        full = run([AIR_VEIR, "aie", "--no-por", "--all-outcomes", "--allow-unregistered-dialect",
                                    f"--max-states={args.max_states}", ag]).stdout
                        def verdict_of(t):
                            return sorted(l.strip() for l in t.splitlines()
                                          if ("deadlock" in l.lower() and "a run" not in l) or "distinct" in l
                                          or l.strip().startswith("%arg"))
                        if "bound reached" not in full and verdict_of(full) != verdict_of(aie):
                            print(f"{name}: POR MISMATCH\n--- por\n{aie}\n--- full\n{full}", flush=True)
                    m = re.search(r"(\d+) distinct outcome", aie)
                    outs = [l.strip() for l in aie.splitlines() if l.strip().startswith("%arg")]
                    if "refused" in aie:
                        verdict = "AIE model refused: " + aie.split("refused: ", 1)[1].splitlines()[0][:120]
                    elif "DEADLOCK" in aie:
                        verdict = "LOWERING BUG: the design deadlocks"
                    elif "bound reached" in aie:
                        verdict = "AIE exploration bound reached"
                    elif m and int(m.group(1)) == 1 and outs == [air_out]:
                        verdict = "ok"
                    elif m and int(m.group(1)) > 1:
                        verdict = f"LOWERING BUG: {m.group(1)} outcomes, the program has 1"
                    else:
                        verdict = f"LOWERING BUG: outcome {outs} differs from {air_out}"
        stats[verdict.split(":")[0]] = stats.get(verdict.split(":")[0], 0) + 1
        print(f"{name}: {verdict}", flush=True)
    print("totals:", stats)
    if not args.keep:
        subprocess.run(["rm", "-rf", tmp])


if __name__ == "__main__":
    main()
