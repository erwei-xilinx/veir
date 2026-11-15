#!/usr/bin/env python3
"""Translation-validate air-dependency on mlir-air's own tests.

Each input file is split at `// -----`. Each chunk is analysed by `air-veir races` twice: as written
(its non-async ops are blocking events, D45) and after `air-opt -air-dependency`. For each
function the verdict is:
- `introduced`: the input is fine, and the output deadlocks or races. air-dependency broke it.
- `inherited`: the input already deadlocks or races (e.g. a fragment whose channels have no
  partner).
- `fragment`: the input puts elements nothing gets; buffered, since its puts are sync (D30), so it
  completes; once async the puts cannot. The input is not a whole program.
- `ok`: neither.
- `output only`: the input could not be analysed, so the output's problems cannot be attributed.
- `input only (async)`: the input is already async (a test of another pass); air-dependency is not
  meant to run on it (it would wrap each `air.execute` in another, AIR-019), so only the input is
  analysed. `async ok` / `async bad` give its verdict.
Chunks the model does not cover are listed with the first reason.

  AIR_OPT=/path/to/air-opt Test/Air/sweep_dependency.py /path/to/mlir-air/mlir/test/Transform/AIRDependency/*.mlir
"""

import os
import re
import subprocess
import sys
import tempfile

AIR_VEIR = ".lake/build/bin/air-veir"
GENERIC = ["--mlir-print-op-generic", "--mlir-print-local-scope"]


def analyse(path):
    """{function: (deadlock, races, errors)}, or a refusal string."""
    try:
        v = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", path],
                           capture_output=True, text=True, timeout=300)
    except subprocess.TimeoutExpired:
        return "TIMEOUT"
    errs = [l for l in v.stderr.splitlines() if not l.startswith("warning")]
    if errs:
        return errs[0][:160]
    out, cur = {}, None
    for line in v.stdout.splitlines():
        m = re.match(r"^@(\w+):.*?(\d+) race\(s\)", line)
        if m:
            cur = m.group(1)
            out[cur] = [False, int(m.group(2)), 0, False]
        elif cur and "DEADLOCK" in line:
            out[cur][0] = True
        elif cur and ("no put provides" in line or "no get takes" in line):
            # Elements nothing takes, or a get nothing feeds: a fragment of a program.
            out[cur][3] = True
            out[cur][2] += line.startswith("  error")
        elif cur and line.startswith("  error"):
            out[cur][2] += 1
    return out


def chunks(air_opt, f, passes):
    r = subprocess.run([air_opt, f, "-split-input-file"] + passes + GENERIC, capture_output=True, text=True)
    if r.returncode:
        return None
    return r.stdout.split("// -----")


def bad(t):
    return t[0] or t[1] > 0 or t[2] > 0


def main():
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    totals = {}
    with tempfile.TemporaryDirectory() as tmp:
        for f in sys.argv[1:]:
            base = os.path.basename(f)[:-len(".mlir")]
            ins, outs = chunks(air_opt, f, []), chunks(air_opt, f, ["-air-dependency"])
            if outs is None:
                print(f"{base}: air-opt failed")
                continue
            for k, chunk in enumerate(outs):
                if "func.func" not in chunk:
                    continue
                tag = f"{base}#{k}"
                if ins is not None and len(ins) == len(outs) and "air.async.token" in ins[k]:
                    pi = os.path.join(tmp, "in.mlir")
                    open(pi, "w").write(ins[k])
                    i = analyse(pi)
                    if isinstance(i, str):
                        print(f"{tag}: REFUSED: {i}")
                        totals["refused"] = totals.get("refused", 0) + 1
                        continue
                    for fn, t in i.items():
                        verdict = "async fragment" if t[3] else ("async bad" if bad(t) else "async ok")
                        totals[verdict] = totals.get(verdict, 0) + 1
                        if verdict == "async bad":
                            print(f"{tag} @{fn}: {verdict}: deadlock={t[0]} races={t[1]} errors={t[2]}")
                    continue
                po, pi = os.path.join(tmp, "out.mlir"), os.path.join(tmp, "in.mlir")
                open(po, "w").write(chunk)
                o = analyse(po)
                if isinstance(o, str):
                    print(f"{tag}: REFUSED: {o}")
                    totals["refused"] = totals.get("refused", 0) + 1
                    continue
                i = "input not split alike"
                if ins is not None and len(ins) == len(outs):
                    open(pi, "w").write(ins[k])
                    i = analyse(pi)
                for fn, t in o.items():
                    if isinstance(i, str) or fn not in i:
                        verdict = "output only" if bad(t) else "ok"
                    elif bad(t) and i[fn][3]:
                        verdict = "fragment"
                    elif bad(t) and not bad(i[fn]):
                        verdict = "introduced"
                    elif bad(i[fn]):
                        verdict = "inherited"
                    else:
                        verdict = "ok"
                    totals[verdict] = totals.get(verdict, 0) + 1
                    if verdict != "ok":
                        why = f" (input refused: {i[:90]})" if isinstance(i, str) and verdict == "output only" else ""
                        print(f"{tag} @{fn}: {verdict}: deadlock={t[0]} races={t[1]} errors={t[2]}{why}")
    print("totals:", totals)


if __name__ == "__main__":
    main()
