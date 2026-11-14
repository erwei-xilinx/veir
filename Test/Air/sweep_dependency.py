#!/usr/bin/env python3
"""Translation-validate air-dependency on mlir-air's own tests.

Each input file (split at `// -----`) goes through `air-opt -air-dependency`; then `air-veir races`
reports, per function, deadlocks (with a checked stuck set), races and channel errors. A deadlock in a
file whose channels are unpaired (a fragment, as many unit tests are) is marked as such; one with
every channel paired is caused by the dependencies. Files the model does not cover are listed
with the first reason.

  AIR_OPT=/path/to/air-opt Test/Air/sweep_dependency.py /path/to/mlir-air/mlir/test/Transform/AIRDependency/*.mlir
"""

import os
import re
import subprocess
import sys
import tempfile

AIR_VEIR = ".lake/build/bin/air-veir"


def main():
    air_opt = os.environ.get("AIR_OPT") or sys.exit("set AIR_OPT to an air-opt binary")
    with tempfile.TemporaryDirectory() as tmp:
        for f in sys.argv[1:]:
            base = os.path.basename(f)[:-len(".mlir")]
            r = subprocess.run([air_opt, f, "-split-input-file", "-air-dependency",
                                "--mlir-print-op-generic", "--mlir-print-local-scope"],
                               capture_output=True, text=True)
            if r.returncode:
                print(f"{base}: air-opt failed")
                continue
            for k, chunk in enumerate(r.stdout.split("// -----")):
                if "func.func" not in chunk:
                    continue
                p = os.path.join(tmp, f"{base}_{k}.mlir")
                open(p, "w").write(chunk)
                tag = f"{base}#{k}"
                try:
                    v = subprocess.run([AIR_VEIR, "races", "--allow-unregistered-dialect", p],
                                       capture_output=True, text=True, timeout=300)
                except subprocess.TimeoutExpired:
                    print(f"{tag}: TIMEOUT")
                    continue
                errs = [l for l in v.stderr.splitlines() if not l.startswith("warning")]
                if errs:
                    print(f"{tag}: REFUSED: {errs[0][:160]}")
                    continue
                funcs = re.findall(r"^@(\w+):.*?(\d+) race\(s\)", v.stdout, re.M)
                dead = re.findall(r"^@(\w+):(?:(?!^@).)*?DEADLOCK", v.stdout, re.M | re.S)
                races = sum(int(n) for _, n in funcs)
                cerr = len(re.findall(r"^  error", v.stdout, re.M))
                # A put no get drains, or a get no put feeds: the file is a fragment, and deadlocks
                # by construction.
                unpaired = len(re.findall(r"no put provides|no get takes", v.stdout))
                kind = "" if not dead else (" (fragment: unpaired channels)" if unpaired else " (DEPENDENCIES)")
                print(f"{tag}: functions={len(funcs)} deadlocked={len(dead)}{kind} {dead if dead else ''} "
                      f"races={races} channel-errors={cerr} unpaired={unpaired}")


if __name__ == "__main__":
    main()
