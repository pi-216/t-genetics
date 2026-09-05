#!/usr/bin/env bash
# test-pr-unwedge.sh — regression tests for pr-unwedge.sh (issue #34).
#
# Builds a throwaway local git origin (bare) + working clone and a stub `gh`
# that reports a fixed set of PRs; asserts pr-unwedge.sh:
#   1. merges main into a DIRTY auto-merge PR whose branch has NO overlap
#      with main's advance, and pushes it (un-wedge), and
#   2. leaves a DIRTY auto-merge PR whose branch DOES overlap main's advance
#      untouched (a clean auto-merge is impossible without manual conflict
#      resolution), and
#   3. never touches draft PRs, cross-repo PRs, PRs without auto-merge
#      enabled, or PRs whose merge state is not DIRTY.
# Also sanity-checks the auto-unwedge workflow manifest.
#
# Pure local execution: no network, no live data, no GitHub API calls.
# Usage: bash .github/scripts/test-pr-unwedge.sh [repo-root]

set -euo pipefail

REPO_ROOT="${1:-$(cd "$(dirname "$0")/../.." && pwd)}"
# absolutize a relative $1 — the fixture cd's into $WORK, so any relative
# path computed before that must not survive it (verified pitfall)
REPO_ROOT="$(cd "$REPO_ROOT" && pwd)"
SCRIPT="$REPO_ROOT/.github/scripts/pr-unwedge.sh"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ORIGIN="$TMP/origin.git"
WORK="$TMP/work"
BIN="$TMP/bin"

# ---------------------------------------------------------------- fixtures --
# Explicit --initial-branch=main: CI runners lack the local
# init.defaultBranch=main global config, so a bare `git init` would create
# `master` and every `git checkout -b X main` below would fail (verified on
# PR #110 lint job: "fatal: 'main' is not a commit").
git init -q --bare --initial-branch=main "$ORIGIN"
git init -q --initial-branch=main "$WORK"
cd "$WORK"
git config user.email test@example.com
git config user.name "test"
git config remote.origin.url "$ORIGIN"
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# base commit on main
printf 'A0\n' > fileA.txt
printf 'B0\n' > fileB.txt
git add -A
git commit -q -m base
TIP_BASE="$(git rev-parse HEAD)"
git push -q origin HEAD:main

# pr-clean: changes ONLY fileA — main's later advance touches only fileB,
# so merging main in is conflict-free (the un-wedgeable case).
git checkout -q -b pr-clean
printf 'A-clean\n' > fileA.txt
git commit -qam "pr-clean change"
git push -q origin HEAD:pr-clean
TIP_CLEAN="$(git rev-parse HEAD)"

# pr-conflict: changes fileB — main's later advance ALSO changes fileB
# to different content, so the merge is genuinely conflicted.
git checkout -q -b pr-conflict main
printf 'B-conflict\n' > fileB.txt
git commit -qam "pr-conflict change"
git push -q origin HEAD:pr-conflict
TIP_CONFLICT="$(git rev-parse HEAD)"

# untouched fixtures (labels matching the stub gh fixture below)
git checkout -q main
for b in pr-draft pr-fork pr-no-auto pr-stale; do
  git branch "$b"
  git push -q origin "$b"
done

# main advances AFTER the PR branches were created (the trigger event)
printf 'B-main\n' > fileB.txt
git commit -qam "main advance (touches fileB)"
MAIN_TIP="$(git rev-parse HEAD)"
git push -q origin HEAD:main

# stub gh: only serves the PR list; delegates nothing else.
# GH_FAKE_FAIL=1 simulates a gh/API outage (e.g. rate limit) for the loud-failure test.
mkdir -p "$BIN"
cat > "$BIN/gh" <<'GHSTUB'
#!/usr/bin/env bash
if [ "${GH_FAKE_FAIL:-0}" = "1" ]; then
  echo "gh: simulated API outage" >&2
  exit 1
fi
if [[ "$*" == *"pr list"* ]]; then
  cat "$GH_FAKE_PR_LIST"
  exit 0
fi
exit 0
GHSTUB
chmod +x "$BIN/gh"

cat > "$TMP/prs.json" <<'EOF'
[
  {"number":101,"headRefName":"pr-clean","mergeStateStatus":"DIRTY","isDraft":false,"isCrossRepository":false,"autoMergeRequest":{"enabledAt":"2026-09-04T00:00:00Z"}},
  {"number":102,"headRefName":"pr-conflict","mergeStateStatus":"DIRTY","isDraft":false,"isCrossRepository":false,"autoMergeRequest":{"enabledAt":"2026-09-04T00:00:00Z"}},
  {"number":103,"headRefName":"pr-draft","mergeStateStatus":"DIRTY","isDraft":true,"isCrossRepository":false,"autoMergeRequest":{"enabledAt":"2026-09-04T00:00:00Z"}},
  {"number":104,"headRefName":"pr-fork","mergeStateStatus":"DIRTY","isDraft":false,"isCrossRepository":true,"autoMergeRequest":{"enabledAt":"2026-09-04T00:00:00Z"}},
  {"number":105,"headRefName":"pr-no-auto","mergeStateStatus":"DIRTY","isDraft":false,"isCrossRepository":false,"autoMergeRequest":null},
  {"number":106,"headRefName":"pr-stale","mergeStateStatus":"UNKNOWN","isDraft":false,"isCrossRepository":false,"autoMergeRequest":{"enabledAt":"2026-09-04T00:00:00Z"}}
]
EOF

# ------------------------------------------------------------------- run ----
fail=0
note() { echo "  ok: $1"; }
bad()  { echo "  FAIL: $1"; fail=1; }

run_script() {
  ( cd "$WORK" && \
    GH_FAKE_PR_LIST="$TMP/prs.json" PATH="$BIN:$PATH" bash "$SCRIPT" > "$TMP/run.log" 2>&1 )
}

echo "== running pr-unwedge.sh against fixture origin" 
run_script
echo "-- script output --"
cat "$TMP/run.log"
echo "--------------------"

# 0. gh outage: must FAIL LOUDLY (non-zero exit), not fake "nothing to do"
if ( cd "$WORK" && \
  GH_FAKE_FAIL=1 GH_FAKE_PR_LIST="$TMP/prs.json" PATH="$BIN:$PATH" bash "$SCRIPT" > "$TMP/outage.log" 2>&1 ); then
  bad "gh outage exited 0 — silent no-op masquerading as 'nothing to do'"
else
  OUTAGE_EXIT=$?
  note "gh outage fails loudly (exit $OUTAGE_EXIT)"
fi
if grep -q "could not list PRs" "$TMP/outage.log"; then
  note "gh outage surfaces an error message"
else
  bad "gh outage produced no error message"
fi
if ! grep -q "no DIRTY auto-merge PRs" "$TMP/outage.log"; then
  note "gh outage does NOT claim 'no DIRTY PRs'"
else
  bad "gh outage falsely reported 'no DIRTY PRs'"
fi

echo "== assertions"
if grep -q "PR #101" "$TMP/run.log"; then note "scans pr-clean (101)"; else bad "pr-clean not scanned"; fi
if grep -q "PR #102" "$TMP/run.log"; then note "scans pr-conflict (102)"; else bad "pr-conflict not scanned"; fi

# 1. pr-clean: main merged in + pushed (pr-clean tip now descends from MAIN_TIP)
if git -C "$ORIGIN" merge-base --is-ancestor "$MAIN_TIP" refs/heads/pr-clean 2>/dev/null; then
  note "main is ancestor of pr-clean (merged + pushed)"
else
  bad "main NOT merged into pr-clean — unwedge did not happen"
fi
CLEAN_TIP_NOW="$(git -C "$ORIGIN" rev-parse refs/heads/pr-clean)"
if [ "$CLEAN_TIP_NOW" != "$TIP_CLEAN" ]; then note "pr-clean tip advanced"; else bad "pr-clean tip unchanged (nothing pushed)"; fi
if grep -q "fileA.txt" <(git -C "$ORIGIN" show "$CLEAN_TIP_NOW":fileA.txt) 2>/dev/null; then :; fi
if [ "$(git -C "$ORIGIN" show "$CLEAN_TIP_NOW":fileA.txt)" = "A-clean" ]; then
  note "pr-clean keeps its own change (branch content preserved)"
else
  bad "pr-clean lost its own change"
fi

# 2. pr-conflict: untouched (cannot auto-merge the conflict)
if [ "$(git -C "$ORIGIN" rev-parse refs/heads/pr-conflict)" = "$TIP_CONFLICT" ]; then
  note "pr-conflict untouched (conflict left for manual resolution)"
else
  bad "pr-conflict was pushed despite merge conflict"
fi

# 3. guards: draft / fork / no-auto-merge / non-DIRTY all untouched
for b in pr-draft pr-fork pr-no-auto pr-stale; do
  if [ "$(git -C "$ORIGIN" rev-parse "refs/heads/$b")" = "$TIP_BASE" ]; then
    note "$b untouched (guard works)"
  else
    bad "$b was modified — guard failed"
  fi
done

# workflow manifest sanity: exists, triggers on push to main, calls the script,
# and checks out with the GH_PAT so the pushed PR branch re-triggers CI
# automatically. A GITHUB_TOKEN push would create pull_request runs in an
# approval-required state (docs.github.com/actions/using-workflows/triggering-a-workflow),
# leaving auto-merge blocked on stale checks — the exact wedge this is meant to fix.
WF="$REPO_ROOT/.github/workflows/auto-unwedge.yml"
if [ -f "$WF" ]; then
  note "auto-unwedge.yml exists"
  if ruby -e 'require "yaml"; YAML.load_file(ARGV[0])' "$WF" 2>/dev/null; then
    note "auto-unwedge.yml parses as YAML"
  else
    bad "auto-unwedge.yml is not valid YAML"
  fi
  if grep -q 'pr-unwedge.sh' "$WF"; then note "workflow invokes pr-unwedge.sh"; else bad "workflow does not call pr-unwedge.sh"; fi
  if grep -q 'secrets.GH_PAT' "$WF"; then note "workflow checks out with GH_PAT (CI re-runs on un-wedged push)"; else bad "workflow does not use GH_PAT for checkout — GITHUB_TOKEN push leaves CI in approval-required state"; fi
else
  bad "auto-unwedge.yml missing"
fi

if [ "$fail" = 1 ]; then
  echo "✗ test-pr-unwedge.sh FAILED"
  exit 1
fi
echo "✓ test-pr-unwedge.sh: all assertions passed"
