#!/usr/bin/env bash
# pr-unwedge.sh — auto-un-wedge merge-conflicted auto-merge PRs (issue #34).
#
# The autonomous pipeline arms auto-merge on every worker PR (CI-only merge
# policy). When main advances — a squash lands, a CI fix lands — every open
# PR whose branch overlaps the change becomes DIRTY (merge-conflicted) and
# GitHub's auto-merge stalls forever with the branch blocked. Nothing in the
# pipeline reacted (pr-requeue only handles review feedback), so the whole PR
# queue wedged for hours (PRD-0002 wave, 2026-09-03).
#
# This script runs on every push to main (see auto-unwedge.yml) and:
#   1. lists open PRs with auto-merge enabled, same-repo, non-draft, whose
#      merge state is DIRTY
#   2. for each, fetches the PR head branch + latest main and attempts a
#      REAL `git merge origin/main` into a detached worktree of the branch
#   3. if the merge is clean, pushes the merged branch — the PR's CI re-runs
#      on the merged result and auto-merge can land it
#   4. if the merge conflicts, leaves the branch untouched — a real conflict
#      needs human/worker judgment (branch-superset vs main-CI-fix rules),
#      never a blind -Xours/-Xtheirs resolution
#
# Only touches PRs where autoMergeRequest != null (pipeline-owned); never
# force-pushes; never resolves conflicts automatically; never rewrites
# existing local refs (worktree is detached, push uses HEAD).
#
# Usage: bash .github/scripts/pr-unwedge.sh [repo] [dry-run]
#   repo      owner/repo (default: $GITHUB_REPOSITORY or pi-216/t-genetics)
#   dry-run   "1" = fetch + report only, no pushes
#
# Requires: gh, jq, git, network access to the repo, `git fetch` permission.

set -euo pipefail

REPO="${1:-${GITHUB_REPOSITORY:-pi-216/t-genetics}}"
DRY_RUN="${2:-0}"

echo "== pr-unwedge: $REPO (dry-run=$DRY_RUN)"

PR_FILE="$(mktemp /tmp/unwedge-prs.XXXXXX)"
MERGE_LOG="$(mktemp /tmp/unwedge-merge.XXXXXX)"
cleanup() { rm -f "$PR_FILE" "$MERGE_LOG"; }
trap cleanup EXIT

# --- 1. find DIRTY, auto-merge-enabled, same-repo, non-draft open PRs -------
# mergeStateStatus values: CLEAN / BLOCKED / BEHIND / DIRTY / DRAFT /
# HAS_HOOKS / UNKNOWN. Only DIRTY means "auto-merge is blocked by a real or
# potential conflict"; BEHIND is auto-healed by GitHub itself.
# `if ! ... | jq` + pipefail makes a gh/jq outage FAIL LOUDLY (exit 1) instead
# of masquerading as "no DIRTY PRs — nothing to do" (a silent no-op).
if ! gh pr list --repo "$REPO" --state open --limit 100 \
    --json number,headRefName,mergeStateStatus,isDraft,isCrossRepository,autoMergeRequest \
    | jq -r '
        .[]
        | select(.mergeStateStatus == "DIRTY")
        | select(.isDraft == false)
        | select(.isCrossRepository == false)
        | select(.autoMergeRequest != null)
        | "\(.number)\t\(.headRefName)"
      ' > "$PR_FILE"; then
  echo "   !! could not list PRs (gh or jq failed) — aborting, no action taken" >&2
  exit 1
fi

mapfile -t DIRTY_PRS < "$PR_FILE"

if [ "${#DIRTY_PRS[@]}" -eq 0 ]; then
  echo "== no DIRTY auto-merge PRs — nothing to do"
  exit 0
fi

echo "== found ${#DIRTY_PRS[@]} DIRTY auto-merge PR(s):"
printf '   %s\n' "${DIRTY_PRS[@]}"

# --- 2. merge main into each PR branch (clean merges only) ------------------
FETCHED_MAIN=0
for entry in "${DIRTY_PRS[@]}"; do
  pr_number="${entry%%$'\t'*}"
  head_ref="${entry#*$'\t'}"
  echo "== PR #$pr_number ($head_ref)"

  if [ "$FETCHED_MAIN" = 0 ]; then
    git fetch -q origin main || { echo "   !! cannot fetch main — aborting"; exit 1; }
    FETCHED_MAIN=1
  fi

  # fetch the PR head into a namespaced remote-tracking ref (never clobbers
  # a local branch; '+' tolerates re-pushed/rewritten PR branches)
  fetch_ref="refs/remotes/origin/pr-unwedge/$pr_number"
  if ! git fetch -q origin "+refs/heads/$head_ref:$fetch_ref"; then
    echo "   !! cannot fetch $head_ref — skipping (deleted branch?)"
    continue
  fi

  worktree="$(mktemp -d /tmp/unwedge.XXXXXX)"
  if ! git worktree add -q --detach "$worktree" "$fetch_ref"; then
    echo "   !! worktree add failed — skipping"
    rm -rf "$worktree"
    continue
  fi

  if ( cd "$worktree" && git -c user.name="t-genetics unwedge bot" \
       -c user.email="unwedge@users.noreply.github.com" \
       merge --no-edit --no-ff origin/main >"$MERGE_LOG" 2>&1; ); then
    if [ "$DRY_RUN" = "1" ]; then
      echo "   ✓ dry-run: would push merged branch $head_ref"
    elif git -C "$worktree" push -q origin "HEAD:refs/heads/$head_ref"; then
      echo "   ✓ merged main into $head_ref and pushed — CI re-runs, auto-merge can land it"
    else
      echo "   !! push failed for $head_ref — left as-is (local merge discarded)"
    fi
  else
    echo "   ⚠ merge of main into $head_ref CONFLICTS (or failed) — branch untouched, leaves for human/worker resolution"
  fi

  git worktree remove --force "$worktree" 2>/dev/null || rm -rf "$worktree"
done

echo "== pr-unwedge done"
