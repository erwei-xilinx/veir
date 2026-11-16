#!/usr/bin/env python3
"""Bounded exhaustive checks of the AIR async layer.

For every program gen.py produces up to the given size, check:

  import  air-opt accepts it; VeIR reads and prints it, and the result is identical to the input
          once both are normalised by air-opt.
  C2      progress: some execution completes (`air-veir run`, proven model: Chan.checkH).
  C3      (--data only) `air-veir graph` warns about a read of an event's result not ordered
          after the event exactly when `air-veir run` reports a race (Chan.racesOk); without
          data, no program races.
  C5      the model's reduction, re-verified by air-opt, passes `air-veir check`; and so does the
          output of AIR's own air-dependency-canonicalize.

Run from the VeIR root after `lake build`:

  AIR_OPT=/path/to/air-opt Test/Air/bounded/check.py --max-events 4
  AIR_OPT=/path/to/air-opt Test/Air/bounded/check.py --max-events 3 --data

Exits non-zero if any check fails, printing the first few failing programs.
"""

import argparse
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
VEIR_OPT = ".lake/build/bin/veir-opt"
AIR_VEIR = ".lake/build/bin/air-veir"
GENERIC = ["--mlir-print-op-generic", "--mlir-print-local-scope"]


def run(cmd, out=None):
    with open(out, "w") if out else open(os.devnull, "w") as f:
        p = subprocess.run(cmd, stdout=subprocess.PIPE if out is None else f,
                           stderr=subprocess.PIPE, text=True)
    return p


def per_func(text):
    """Split tool output into {function name: [lines]}."""
    funcs, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^(?:OK |FAIL )?@(\w+)", line)
        if m:
            cur = m.group(1)
            funcs.setdefault(cur, []).append(line)
        elif cur is not None:
            funcs[cur].append(line)
    return funcs


def check_file(air_opt, path, data, tmp, report):
    name = os.path.basename(path)
    ok = True

    def fail(what, detail=""):
        nonlocal ok
        ok = False
        report.append(f"{name}: {what}{': ' + detail if detail else ''}")

    # Import.
    if run([air_opt, path, "-o", os.devnull]).returncode != 0:
        fail("air-opt rejects the generated input")
        return ok
    v = os.path.join(tmp, "v.mlir")
    if run([VEIR_OPT, "--print-op-generic", path], v).returncode != 0:
        fail("VeIR does not read it")
        return ok
    n1, n2 = os.path.join(tmp, "norm_in.mlir"), os.path.join(tmp, "norm_veir.mlir")
    run([air_opt, path] + GENERIC, n1)
    if run([air_opt, v] + GENERIC, n2).returncode != 0:
        fail("air-opt rejects VeIR's output")
    elif open(n1).read() != open(n2).read():
        fail("round trip differs after normalisation")

    # C2, and C3 in --data mode.
    r = run([AIR_VEIR, "run", path])
    if r.returncode != 0:
        fail("air-veir run failed", r.stderr.strip()[:200])
        return ok
    runs = per_func(r.stdout)
    warns = {}
    if data:
        g = run([AIR_VEIR, "graph", path])
        warns = {f: any("warning:" in l for l in ls) for f, ls in per_func(g.stdout).items()}
    # `run` answers from the proven channel model: "deadlocks" (Chan.checkH_false), or the outcome
    # with "race-free" (Chan.outcome_uniqueH) or "races".
    for f, lines in runs.items():
        text = "\n".join(lines)
        if "deadlocks" in text:
            fail(f"@{f}: C2 no complete execution")
            continue
        raced = any(l.startswith("  races") for l in lines)
        if not raced and not any(l.startswith("  race-free") for l in lines):
            fail(f"@{f}: no run summary")
            continue
        if data:
            racy = warns.get(f, False)
            if racy != raced:
                fail(f"@{f}: C3 warning={racy} but run reports races={raced}")
        elif raced:
            fail(f"@{f}: races without data")

    # C5: the model's reduction.
    red = os.path.join(tmp, "r.mlir")
    if run([AIR_VEIR, "reduce", path], red).returncode != 0:
        fail("air-veir reduce failed")
    elif run([air_opt, red, "-o", os.devnull]).returncode != 0:
        fail("air-opt rejects the reduction")
    else:
        c = run([AIR_VEIR, "check", path, red])
        for f, ls in per_func(c.stdout).items():
            if not ls[0].startswith("OK"):
                fail(f"@{f}: C5 model reduction", " | ".join(ls))

    # C5: AIR's own pass.
    cxx = os.path.join(tmp, "c.mlir")
    p = run([air_opt, path, "-air-dependency-canonicalize"] + GENERIC, cxx)
    if p.returncode != 0:
        fail("air-dependency-canonicalize failed", p.stderr.strip()[:300])
    else:
        c = run([AIR_VEIR, "check", path, cxx])
        if not c.stdout.strip():
            fail("air-veir check on the C++ output failed", c.stderr.strip()[:300])
        for f, ls in per_func(c.stdout).items():
            if not ls[0].startswith("OK"):
                fail(f"@{f}: C5 air-dependency-canonicalize", " | ".join(ls))
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--max-events", type=int, required=True)
    ap.add_argument("--data", action="store_true")
    ap.add_argument("--show", type=int, default=10, help="failures to print")
    ap.add_argument("--chunk", type=int, default=500, help="functions per module")
    ap.add_argument("--body-ops", type=int, default=0,
                    help="without --data, arith.constants in every air.execute body")
    args = ap.parse_args()
    air_opt = os.environ.get("AIR_OPT")
    if not air_opt:
        sys.exit("set AIR_OPT to an air-opt binary")
    report, total = [], 0
    with tempfile.TemporaryDirectory() as tmp:
        for n in range(1, args.max_events + 1):
            cmd = [sys.executable, os.path.join(HERE, "gen.py"), "--events", str(n)]
            if args.data:
                cmd.append("--data")
            if args.body_ops:
                cmd += ["--body-ops", str(args.body_ops)]
            g = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            count = int(g.stderr.split()[0])
            total += count
            # air-dependency-canonicalize takes time superlinear in the number of functions in a
            # module, so the programs are checked in modules of --chunk functions.
            body = g.stdout.split("\n", 1)[1].rsplit("}) : () -> ()", 1)[0]
            funcs = [f for f in re.split(r'(?=  "func.func")', body) if f.strip()]
            before = len(report)
            for c in range(0, len(funcs), args.chunk):
                path = os.path.join(tmp, f"events{n}_{c // args.chunk}.mlir")
                with open(path, "w") as f:
                    f.write('"builtin.module"() ({\n' + "".join(funcs[c:c + args.chunk]) + "}) : () -> ()\n")
                check_file(air_opt, path, args.data, tmp, report)
            status = "ok" if len(report) == before else f"{len(report) - before} failure(s)"
            what = " with data" if args.data else (f" with {args.body_ops}-op bodies" if args.body_ops else "")
            print(f"{count:6} program(s) of {n} event(s){what}: {status}",
                  flush=True)
    print(f"{total} program(s) checked, {len(report)} failure(s)")
    for line in report[: args.show]:
        print("  " + line)
    sys.exit(1 if report else 0)


if __name__ == "__main__":
    main()
