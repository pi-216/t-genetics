#!/usr/bin/env bash
# test-po-acceptance-state.sh — regression tests for po-acceptance-state.sh
# (issue #152: PO acceptance gate — the browser-truth loop after merge).
#
# Drives the monitor against a stub `gh` serving fixed issue fixtures and a
# throwaway pass book; asserts the deterministic phase-token contract:
#   OPEN:PO_READY:<PRD-tags>  — complete-without-pass epics (sorted, unique)
#   OPEN:PO_NONE              — no complete-without-pass PRD
#   OPEN:UNKNOWN              — gh/jq unavailable, garbage gh output, or a
#                               malformed pass book (fail-closed: a PO pass
#                               must NEVER fire on unknown state)
# Acceptance criteria exercised (issue #152):
#   - an epic whose approved+ticket children all merged triggers ONE pass
#     (idempotent — a passed PRD never re-fires)  -> cases 1,2,6,7
#   - unfinished epics, unapproved children, and non-PRD epics never fire
#     -> cases 3,4,5,12,13
#   - unknown state fails closed                          -> cases 8,9,10,11
#
# Pure local execution: no network, no live data, no GitHub API calls.
# Usage: bash .github/scripts/test-po-acceptance-state.sh [repo-root]

set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
SCRIPT="$REPO_ROOT/.github/scripts/po-acceptance-state.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

BIN="$TMP/bin"
PASS_BOOK="$TMP/passbook.json"
mkdir -p "$BIN"

# -------------------------------------------------------------- stub gh ----
# GH_FAKE_FAIL=1 simulates a gh/API outage; otherwise serves the fixture file.
cat > "$BIN/gh" <<'GHSTUB'
#!/usr/bin/env bash
if [ "${GH_FAKE_FAIL:-0}" = "1" ]; then
  echo "gh: simulated API outage" >&2
  exit 1
fi
cat "$GH_FAKE_ISSUES"
GHSTUB
chmod +x "$BIN/gh"

# ------------------------------------------------------------- fixtures ----
# A: one ready epic (all approved+ticket children closed, no pass recorded)
FIX_A="$TMP/fix_a.json"
cat > "$FIX_A" <<'EOF'
[
  {"number":76,"title":"[PRD] PRD-0004 — Graphical chromosome designer & generation browser","state":"open","labels":[{"name":"ticket"}]},
  {"number":77,"title":"[PRD-0004] A user designs a chromosome with mixed allele types and sees a live preview","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]},
  {"number":78,"title":"[PRD-0004] Allele bounds are validated inline","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]}
]
EOF

# B: two ready epics; PRD-0004 array-first to prove the token sorts tags
FIX_B="$TMP/fix_b.json"
cat > "$FIX_B" <<'EOF'
[
  {"number":76,"title":"[PRD] PRD-0004 — Graphical chromosome designer & generation browser","state":"open","labels":[{"name":"ticket"}]},
  {"number":77,"title":"[PRD-0004] A user designs a chromosome with mixed allele types and sees a live preview","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]},
  {"number":67,"title":"[PRD] PRD-0003 — Experiment workspace (the loop, in the UI)","state":"open","labels":[{"name":"ticket"}]},
  {"number":68,"title":"[PRD-0003] A member creates an experiment with a chromosome and population size","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]}
]
EOF

# C: no epics at all
FIX_C="$TMP/fix_c.json"
printf '[{"number":1,"title":"ops: something unrelated","state":"open","labels":[{"name":"ticket"}]}]\n' > "$FIX_C"

# D: epic whose children carry ticket but NOT approved (never gates on them)
FIX_D="$TMP/fix_d.json"
cat > "$FIX_D" <<'EOF'
[
  {"number":76,"title":"[PRD] PRD-0004 — Graphical chromosome designer & generation browser","state":"open","labels":[{"name":"ticket"}]},
  {"number":77,"title":"[PRD-0004] A user designs a chromosome with mixed allele types and sees a live preview","state":"closed","labels":[{"name":"ticket"}]}
]
EOF

# E: unfinished epic — one approved+ticket child still open
FIX_E="$TMP/fix_e.json"
cat > "$FIX_E" <<'EOF'
[
  {"number":76,"title":"[PRD] PRD-0004 — Graphical chromosome designer & generation browser","state":"open","labels":[{"name":"ticket"}]},
  {"number":77,"title":"[PRD-0004] A user designs a chromosome with mixed allele types and sees a live preview","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]},
  {"number":78,"title":"[PRD-0004] Allele bounds are validated inline","state":"open","labels":[{"name":"approved"},{"name":"ticket"}]}
]
EOF

# L: hostile epic/child titles must never reach the token (tag regex guard).
# The evil epic gets a REAL child matching its tag — without the guard the
# "$$$" tag would leak into the token (the children gate alone cannot save it).
FIX_L="$TMP/fix_l.json"
cat > "$FIX_L" <<'EOF'
[
  {"number":76,"title":"[PRD] PRD-0004 — Graphical chromosome designer & generation browser","state":"open","labels":[{"name":"ticket"}]},
  {"number":77,"title":"[PRD-0004] A user designs a chromosome with mixed allele types and sees a live preview","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]},
  {"number":999,"title":"[PRD] $$$ ; touch /tmp/po-acceptance-pwned","state":"open","labels":[{"name":"ticket"}]},
  {"number":1001,"title":"[$$$] Ghost child of the evil epic","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]},
  {"number":1000,"title":"[PRD-$(touch /tmp/po-acceptance-pwned)] Hijack child","state":"closed","labels":[{"name":"approved"},{"name":"ticket"}]}
]
EOF

# M: epic with zero children
FIX_M="$TMP/fix_m.json"
printf '[{"number":76,"title":"[PRD] PRD-0009 — Brand new epic","state":"open","labels":[{"name":"ticket"}]}]\n' > "$FIX_M"

FIX_GARBAGE="$TMP/fix_garbage.json"
printf 'this is not json at all\n' > "$FIX_GARBAGE"

# ------------------------------------------------------------ helpers ----
fail=0
note() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1"; fail=1; }

expect_token() { # <name> <fixture> <pass-book-content> <expected> [env...]
  local name="$1" fixture="$2" pb="$3" expected="$4"
  shift 4
  printf '%s' "$pb" > "$PASS_BOOK"
  local out extra=()
  # extra env args ride `env`, never "$@" in command position — a "$@" that
  # expands empty strands the first VAR=word in the command-name slot and bash
  # tries to EXECUTE it (127: "TGEN_PO_REPO=pi-216/t-genetics: No such file")
  [ "$#" -gt 0 ] && extra=("$@")
  out=$( cd "$TMP" && env \
      TGEN_PO_REPO=pi-216/t-genetics \
      TGEN_PO_REPO_DIR="$TMP" TGEN_PO_PASS_BOOK="$PASS_BOOK" \
      TGEN_PO_GH="$BIN/gh" GH_FAKE_ISSUES="$fixture" \
      PATH="$BIN:$PATH" "${extra[@]}" bash "$SCRIPT" 2>"$TMP/err.log" ) || {
    bad "$name: script exited nonzero ($?) on a determinable state"
    if [ -s "$TMP/err.log" ]; then
      echo "    stderr: $(tr '\n' ' ' < "$TMP/err.log")"
    fi
    return
  }
  if [ "$out" = "$expected" ]; then
    note "$name -> $out"
  else
    bad "$name: expected '$expected' got '$out'"
  fi
}

# ------------------------------------------------------------ cases ----
echo "== phase-token contract"

expect_token "ready epic fires once"        "$FIX_A" "[]" "OPEN:PO_READY:PRD-0004"
expect_token "two ready epics, sorted"      "$FIX_B" "[]" "OPEN:PO_READY:PRD-0003,PRD-0004"
expect_token "no epics -> PO_NONE"          "$FIX_C" "[]" "OPEN:PO_NONE"
expect_token "unapproved children ignored"  "$FIX_D" "[]" "OPEN:PO_NONE"
expect_token "open child blocks the epic"   "$FIX_E" "[]" "OPEN:PO_NONE"
expect_token "epic with no children -> none" "$FIX_M" "[]" "OPEN:PO_NONE"
expect_token "hostile titles never leak"    "$FIX_L" "[]" "OPEN:PO_READY:PRD-0004"
if [ ! -e /tmp/po-acceptance-pwned ]; then
  note "hostile titles executed nothing"
else
  bad "hostile title payload executed (file /tmp/po-acceptance-pwned created)"
fi

echo "== idempotency (one pass per PRD)"
expect_token "passed PRD never re-fires"     "$FIX_A" '["PRD-0004"]' "OPEN:PO_NONE"
expect_token "mixed pass book skips passed"  "$FIX_B" '["PRD-0003"]' "OPEN:PO_READY:PRD-0004"

echo "== fail-closed unknown state"
expect_token "gh outage -> UNKNOWN"     "$FIX_A" "[]" "OPEN:UNKNOWN" GH_FAKE_FAIL=1
expect_token "garbage gh output"        "$FIX_GARBAGE" "[]" "OPEN:UNKNOWN"
expect_token "malformed pass book"      "$FIX_A" '{"not":"an array"}' "OPEN:UNKNOWN"
expect_token "non-array pass book"      "$FIX_A" "garbage" "OPEN:UNKNOWN"

# jq missing -> the command -v guard reports UNKNOWN (locate jq, rebuild PATH
# without its dir, mirroring CI runners that lack jq)
if command -v jq >/dev/null 2>&1; then
  JQ_DIR="$(dirname "$(command -v jq)")"
  NOJQ_PATH="$(printf '%s' "$PATH" | tr ':' '\n' | grep -v -x "$JQ_DIR" | paste -sd: -)"
  out=$( cd "$TMP" && TGEN_PO_REPO=pi-216/t-genetics TGEN_PO_REPO_DIR="$TMP" \
      TGEN_PO_PASS_BOOK="$PASS_BOOK" TGEN_PO_GH="$BIN/gh" GH_FAKE_ISSUES="$FIX_A" \
      PATH="$BIN:$NOJQ_PATH" bash "$SCRIPT" 2>"$TMP/err.log" ) || true
  if [ "$out" = "OPEN:UNKNOWN" ]; then
    note "jq missing -> UNKNOWN"
  else
    bad "jq missing: expected 'OPEN:UNKNOWN' got '$out'"
  fi
else
  bad "test environment has no jq — cannot verify the missing-jq branch"
fi

# ------------------------------------------------------------- wiring ----
echo "== repo wiring"
RUNBOOK="$REPO_ROOT/docs/ops/po-acceptance.md"
if [ -f "$RUNBOOK" ]; then
  note "docs/ops/po-acceptance.md exists"
else
  bad "po-acceptance runbook missing (the monitor script references it)"
fi
if grep -q 'test-po-acceptance-state.sh' "$REPO_ROOT/.github/workflows/ci.yml"; then
  note "ci.yml lint job runs test-po-acceptance-state.sh"
else
  bad "ci.yml does not run the PO monitor regression test"
fi

# ------------------------------------------------------------ verdict ----
if [ "$fail" = 1 ]; then
  echo "✗ test-po-acceptance-state.sh FAILED"
  exit 1
fi
echo "✓ test-po-acceptance-state.sh: all assertions passed"