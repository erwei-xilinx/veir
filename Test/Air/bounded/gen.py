#!/usr/bin/env python3
"""Enumerate every AIR async program up to a given number of events.

An event is one of
  exec   %e = air.execute [deps] { ... }        (token, and in --data mode an i32 result)
  async  %e = air.wait_all async [deps]          (token)
  block  air.wait_all [deps]                     (blocking; no token, so nothing can name it)

and its dependencies are any subset of the earlier events that have a token. In --data mode each
air.execute also reads the i32 results of any subset of the earlier air.executes, adding them to a
constant of its own, so that every program computes something and a read can race.

Programs are written as the functions @p0, @p1, ... of one module, in MLIR's generic form, which
both air-opt and VeIR read. The enumeration is exhaustive: no symmetry is factored out.

  gen.py --events 4 > graphs4.mlir
  gen.py --events 3 --data > data3.mlir
"""

import argparse
import itertools
import sys

KINDS = ("exec", "async", "block")


def subsets(xs):
    for r in range(len(xs) + 1):
        yield from itertools.combinations(xs, r)


def programs(n, data):
    """Yield every program of exactly n events, as a list of (kind, deps, reads)."""

    def go(prefix):
        if len(prefix) == n:
            yield list(prefix)
            return
        i = len(prefix)
        producers = [j for j, (k, _, _) in enumerate(prefix) if k != "block"]
        execs = [j for j, (k, _, _) in enumerate(prefix) if k == "exec"]
        for kind in KINDS:
            for deps in subsets(producers):
                reads_choices = subsets(execs) if (data and kind == "exec") else [()]
                for reads in reads_choices:
                    prefix.append((kind, deps, reads))
                    yield from go(prefix)
                    prefix.pop()

    yield from go([])


def emit(name, prog, data):
    tok = (lambda j: f"%e{j}#0") if data else (lambda j: f"%e{j}")
    lines = [f'  "func.func"() <{{function_type = () -> (), sym_name = "{name}"}}> ({{']
    for i, (kind, deps, reads) in enumerate(prog):
        args = ", ".join(tok(j) for j in deps)
        types = ", ".join("!air.async.token" for _ in deps)
        if kind == "block":
            lines.append(f'    "air.wait_all"({args}) : ({types}) -> ()')
        elif kind == "async":
            lines.append(f'    %e{i} = "air.wait_all"({args}) : ({types}) -> !air.async.token')
        elif not data:
            lines.append(f'    %e{i} = "air.execute"({args}) ({{')
            lines.append('      "air.execute_terminator"() : () -> ()')
            lines.append(f"    }}) : ({types}) -> !air.async.token")
        else:
            lines.append(f'    %e{i}:2 = "air.execute"({args}) ({{')
            lines.append(f'      %c{i} = "arith.constant"() <{{value = {10 ** i} : i32}}> : () -> i32')
            acc = f"%c{i}"
            for j in reads:
                lines.append(
                    f'      %s{i}_{j} = "arith.addi"({acc}, %e{j}#1) '
                    "<{overflowFlags = #arith.overflow<none>}> : (i32, i32) -> i32"
                )
                acc = f"%s{i}_{j}"
            lines.append(f'      "air.execute_terminator"({acc}) : (i32) -> ()')
            lines.append(f"    }}) : ({types}) -> (!air.async.token, i32)")
    lines.append('    "func.return"() : () -> ()')
    lines.append("  }) : () -> ()")
    return "\n".join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--events", type=int, required=True, help="number of events in every program")
    ap.add_argument("--data", action="store_true", help="air.executes yield and read i32 values")
    args = ap.parse_args()
    out = sys.stdout
    out.write('"builtin.module"() ({\n')
    count = 0
    for prog in programs(args.events, args.data):
        out.write(emit(f"p{count}", prog, args.data) + "\n")
        count += 1
    out.write("}) : () -> ()\n")
    print(f"{count} programs of {args.events} event(s)", file=sys.stderr)


if __name__ == "__main__":
    main()
