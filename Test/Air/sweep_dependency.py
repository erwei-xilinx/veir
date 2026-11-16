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

Scalar (index, integer) arguments: a chunk whose functions take any is analysed once per value
in 0, 1, 2, 3 and the `scf.index_switch` case values in it, every scalar argument getting that
value (`--args`). Each verdict holds for its input (D59). A function's verdict is the worst over
the values (introduced > output only > inherited > fragment > ok), listed per value when they
differ. Chunks without scalar arguments are analysed once. While some branch region is unreached, vectors
whose arguments differ (one of the first 4 positions changed) are tried as well. After each
function with branch ops
(`scf.if`, `affine.if`, `scf.index_switch`), the regions no value reached on the input are listed:
those parts of the program were not checked. Coverage is reported by the instantiation (glue), not
proven.

  AIR_OPT=/path/to/air-opt Test/Air/sweep_dependency.py /path/to/mlir-air/mlir/test/Transform/AIRDependency/*.mlir
"""

import os
import re
import subprocess
import sys
import tempfile

AIR_VEIR = ".lake/build/bin/air-veir"
GENERIC = ["--mlir-print-op-generic", "--mlir-print-local-scope"]
RANK = ["introduced", "output only", "inherited", "fragment", "ok"]
ASYNC_RANK = ["async bad", "async fragment", "async ok"]


def analyse(path, value):
    """{function: [deadlock, races, errors, fragment, branches]}, or a refusal string. `branches`
    is a list of (name, regions, taken regions). `value` is one integer for every scalar argument,
    or a tuple of them in order."""
    vec = list(value) if isinstance(value, tuple) else [value]
    args = ["--args=" + ",".join(str(x) for x in (vec + [vec[-1]] * 16)[:16])]
    try:
        v = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect"] + args + [path],
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
            out[cur] = [False, int(m.group(2)), 0, False, []]
        elif cur and line.startswith("  branches reached"):
            out[cur][4] = [(n, int(k), [int(x) for x in rs.split(",") if x.strip()])
                           for n, rs, k in re.findall(r"#\d+ (\S+) took \[([\d, ]*)\] of (\d+)", line)]
        elif cur and "DEADLOCK" in line:
            out[cur][0] = True
        elif cur and ("are never got" in line or "no put provides" in line or "no get takes" in line):
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


def scalar_values(chunk):
    """The values to try for a chunk's scalar arguments; [2] when it has none."""
    def bare(sig):
        while True:
            s2 = re.sub(r"<[^<>]*>", "", sig)
            if s2 == sig:
                return s2
            sig = s2
    has = any(re.search(r"\b(i\d+|index)\b", bare(sig))
              for sig in re.findall(r"function_type = \(([^)]*)\)", chunk))
    if not has:
        return [2]
    vals = {0, 1, 2, 3}
    for cases in re.findall(r"cases = array<i64: ([^>]*)>", chunk):
        vals |= {int(x) for x in cases.split(",") if x.strip()}
    return sorted(vals)[:8]


def show(t):
    return f"deadlock={t[0]} races={t[1]} errors={t[2]}"


def worst(verdicts, rank):
    return min(verdicts, key=rank.index)


def main():
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    totals = {}
    arms = [0, 0]  # regions reached, regions in all
    with tempfile.TemporaryDirectory() as tmp:
        pi, po = os.path.join(tmp, "in.mlir"), os.path.join(tmp, "out.mlir")
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
                same = ins is not None and len(ins) == len(outs)
                is_async = same and "air.async.token" in ins[k]
                values = scalar_values(ins[k] if same else chunk)
                if same:
                    open(pi, "w").write(ins[k])
                open(po, "w").write(chunk)
                # function -> [(value, verdict, detail)]; function -> branch coverage
                per, cov, refusals = {}, {}, []
                for val in values:
                    if is_async:
                        i = analyse(pi, val)
                        if isinstance(i, str):
                            refusals.append((val, i))
                            if i == "TIMEOUT":
                                break
                            continue
                        for fn, t in i.items():
                            v = "async fragment" if t[3] else ("async bad" if bad(t) else "async ok")
                            per.setdefault(fn, []).append((val, v, show(t)))
                            cov.setdefault(fn, []).append(t[4])
                        continue
                    o = analyse(po, val)
                    if isinstance(o, str):
                        refusals.append((val, o))
                        if o == "TIMEOUT":
                            break
                        continue
                    i = analyse(pi, val) if same else "input not split alike"
                    for fn, t in o.items():
                        why = ""
                        if isinstance(i, str) or fn not in i:
                            v = "output only" if bad(t) else "ok"
                            if isinstance(i, str) and v == "output only":
                                why = f" (input refused: {i[:90]})"
                        elif bad(t) and i[fn][3]:
                            v = "fragment"
                        elif bad(t) and not bad(i[fn]):
                            v = "introduced"
                        elif bad(i[fn]):
                            v = "inherited"
                        else:
                            v = "ok"
                        per.setdefault(fn, []).append((val, v, show(t) + why))
                        cov.setdefault(fn, []).append(i[fn][4] if not isinstance(i, str) and fn in i else t[4])
                # Branch regions still unreached: try arguments that differ, one position at a
                # time (up to 4 positions), until every region is reached.
                def unreached():
                    left = 0
                    for fn in cov:
                        runs = [c for c in cov[fn] if c]
                        if not runs:
                            continue
                        for j, (_, n, _) in enumerate(runs[0]):
                            took = set().union(*[set(c[j][2]) for c in runs if j < len(c)])
                            left += n - len(took & set(range(n)))
                    return left
                if len(values) > 1 and per and unreached():
                    extra = [tuple(u if q != p else w for q in range(4))
                             for p in range(4) for u in values for w in values if w != u]
                    for vec in extra:
                        if not unreached():
                            break
                        t_in = analyse(pi if is_async or same else po, vec)
                        if isinstance(t_in, str):
                            continue
                        for fn, t in t_in.items():
                            if fn in cov:
                                cov[fn].append(t[4])
                                if is_async:
                                    v = "async fragment" if t[3] else ("async bad" if bad(t) else "async ok")
                                    per[fn].append((vec, v, show(t)))
                        if not is_async:
                            o = analyse(po, vec)
                            if isinstance(o, str) or not same:
                                continue
                            for fn, t in o.items():
                                if fn not in per or fn not in t_in:
                                    continue
                                i_t = t_in[fn]
                                if bad(t) and i_t[3]:
                                    v = "fragment"
                                elif bad(t) and not bad(i_t):
                                    v = "introduced"
                                elif bad(i_t):
                                    v = "inherited"
                                else:
                                    v = "ok"
                                per[fn].append((vec, v, show(t)))
                if not per:
                    val, why = refusals[0]
                    print(f"{tag}: REFUSED: {why}")
                    totals["refused"] = totals.get("refused", 0) + 1
                    continue
                for val, why in refusals:
                    print(f"{tag}: with {val}: REFUSED: {why}")
                for fn, rs in per.items():
                    rank = ASYNC_RANK if is_async else RANK
                    v = worst([r[1] for r in rs], rank)
                    totals[v] = totals.get(v, 0) + 1
                    if v not in ("ok", "async ok"):
                        if len({r[1] for r in rs}) == 1 and len({r[2] for r in rs}) == 1:
                            vals = "" if len(rs) == 1 else f" (with {', '.join(str(r[0]) for r in rs)})"
                            print(f"{tag} @{fn}: {v}: {rs[0][2]}{vals}")
                        else:
                            print(f"{tag} @{fn}: {v}: " + "; ".join(f"with {r[0]}: {r[1]} {r[2]}" for r in rs))
                    # Branch regions no value reached, by branch op.
                    runs = [c for c in cov[fn] if c]
                    if not runs:
                        continue
                    missing = []
                    for j, (name, n, _) in enumerate(runs[0]):
                        took = set()
                        for c in runs:
                            if j < len(c):
                                took |= set(c[j][2])
                        arms[0] += len(took & set(range(n)))
                        arms[1] += n
                        left = sorted(set(range(n)) - took)
                        if left:
                            missing.append(f"#{j} {name} regions {left} of {n}")
                    if missing:
                        print(f"{tag} @{fn}: not reached by {values} (and mixed vectors): " + "; ".join(missing))
    print("totals:", totals)
    print(f"branch regions reached on the inputs: {arms[0]} of {arms[1]}")


if __name__ == "__main__":
    main()
