#!/usr/bin/env bash
# Checks that need MLIR-AIR's own air-opt, which VeIR's lit suite does not assume.
#
#   AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh            # the fixtures
#   AIR_OPT=/path/to/air-opt Test/Air/air-integration.sh --sweep DIR  # also every .mlir under DIR
#
# For each fixture:
#   1. VeIR reads and prints it, air-opt re-verifies VeIR's output, and the two are compared after
#      both are normalised by air-opt's generic printer (so SSA names and attribute order do not
#      matter, but every operation, operand, type, region and attribute does).
#   2. If it is in the supported subset: air-veir's reduction is re-verified by air-opt and checked
#      against the input, and so is the output of AIR's own air-dependency-canonicalize.
#
# Run from the VeIR root after `lake build`.
set -u
AIR_OPT=${AIR_OPT:?set AIR_OPT to an air-opt binary}
VEIR_OPT=.lake/build/bin/veir-opt
AIR_VEIR=.lake/build/bin/air-veir
GENERIC="--mlir-print-op-generic --mlir-print-local-scope"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail=0

# roundtrip <generic input> -> 0 identical, 1 VeIR refused it, 2 air-opt refused VeIR's output,
# 3 different after normalisation.
roundtrip() {
  "$VEIR_OPT" --allow-unregistered-dialect --print-op-generic "$1" > "$TMP/v.mlir" 2> "$TMP/v.err" || return 1
  "$AIR_OPT" "$TMP/v.mlir" $GENERIC > "$TMP/n2.mlir" 2> "$TMP/a.err" || return 2
  "$AIR_OPT" "$1" $GENERIC > "$TMP/n1.mlir" 2>/dev/null || return 2
  cmp -s "$TMP/n1.mlir" "$TMP/n2.mlir" || return 3
  return 0
}

# semantic <generic input> <label>: reduce, re-verify, check; then check AIR's own pass.
semantic() {
  if ! "$AIR_VEIR" graph --allow-unregistered-dialect "$1" > /dev/null 2> "$TMP/g.err"; then
    echo "  [$2] outside the supported subset: $(head -c 160 "$TMP/g.err")"
    return 0
  fi
  "$AIR_VEIR" reduce "$1" > "$TMP/r.mlir" || { echo "  [$2] FAIL: reduce"; return 1; }
  "$AIR_OPT" "$TMP/r.mlir" -o /dev/null || { echo "  [$2] FAIL: air-opt rejects the reduction"; return 1; }
  echo "  [$2] reduction: $("$AIR_VEIR" check "$1" "$TMP/r.mlir")" || return 1
  "$AIR_OPT" "$1" -air-dependency-canonicalize $GENERIC > "$TMP/c.mlir" 2>/dev/null \
    || { echo "  [$2] air-dependency-canonicalize failed on it"; return 0; }
  if out=$("$AIR_VEIR" check "$1" "$TMP/c.mlir"); then
    echo "  [$2] air-dependency-canonicalize: $out"
  else
    echo "  [$2] FAIL air-dependency-canonicalize: $out"; return 1
  fi
}

echo "== fixtures"
for f in Test/Air/fixture_*.mlir.in; do
  roundtrip "$f"; rc=$?
  case $rc in
    0) echo "  [$f] round trip: identical after air-opt normalisation" ;;
    *) echo "  [$f] FAIL round trip ($rc)"; fail=1 ;;
  esac
  semantic "$f" "$f" || fail=1
done

if [ "${1:-}" = "--sweep" ]; then
  dir=${2:?--sweep needs a directory}
  echo "== sweep of $dir"
  n=0; skipped=0; ok=0; refused=0; noverify=0; differ=0; insubset=0; cxxok=0; cxxfail=0
  while IFS= read -r f; do
    n=$((n + 1))
    # Inputs air-opt does not accept as one module (expected-error tests, split files) are skipped.
    if grep -q -- "-split-input-file\|expected-error" "$f" ||
       ! "$AIR_OPT" "$f" $GENERIC > "$TMP/in.mlir" 2>/dev/null; then
      skipped=$((skipped + 1)); continue
    fi
    roundtrip "$TMP/in.mlir"; rc=$?
    case $rc in
      0) ok=$((ok + 1)) ;;
      1) refused=$((refused + 1)); echo "  refused: $f: $(grep -m1 -o 'error.*' "$TMP/v.err" | head -c 140)" >> "$TMP/refused.txt" ;;
      2) noverify=$((noverify + 1)); echo "  air-opt rejects VeIR output: $f" ;;
      3) differ=$((differ + 1)); echo "  differs after round trip: $f" ;;
    esac
    if "$AIR_VEIR" graph "$TMP/in.mlir" > /dev/null 2>&1; then
      insubset=$((insubset + 1))
      if "$AIR_OPT" "$TMP/in.mlir" -air-dependency-canonicalize $GENERIC > "$TMP/c.mlir" 2>/dev/null; then
        if "$AIR_VEIR" check "$TMP/in.mlir" "$TMP/c.mlir" > "$TMP/chk.txt"; then
          cxxok=$((cxxok + 1))
        else
          cxxfail=$((cxxfail + 1)); echo "  canonicalize output rejected: $f"; cat "$TMP/chk.txt"
        fi
      fi
    fi
  done < <(find "$dir" -name '*.mlir' | sort)
  echo "  $n files; $skipped skipped (expected-error, split-input or not accepted by air-opt)"
  echo "  round trip: $ok identical, $differ different, $noverify not re-verified, $refused refused by VeIR's parser"
  echo "  in the semantic subset: $insubset; air-dependency-canonicalize output accepted by the checker: $cxxok, rejected: $cxxfail"
  if [ -s "$TMP/refused.txt" ]; then
    echo "  most common reasons VeIR's parser refused a file:"
    sed 's/^  refused: [^:]*: //' "$TMP/refused.txt" | sed 's/[0-9]\+:[0-9]\+//g' | sort | uniq -c | sort -rn | head -8
  fi
  [ $differ -eq 0 ] && [ $noverify -eq 0 ] && [ $cxxfail -eq 0 ] || fail=1
fi

exit $fail
