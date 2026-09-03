#!/usr/bin/env bash
# pr-requeue.sh — return a PR-with-review-feedback back to the autonomous
# pipeline's actionable list (issue #N, {repo} harness). Port from t-chat.
#
# Triggered by the pr-requeue workflow on pull_request_review (non-approved)
# and pull_request_review_comment (new inline comment) events.
#   1. reopen the linked issue ("Closes #N" from the PR body)
#   2. strip claim/block labels (agent_working/agent_blocked/agent_needs_review)
#   3. set the board Status back to Todo (needs GH_PAT — GITHUB_TOKEN cannot
#      use the Projects API)
#   4. append the review feedback to the issue body (worker reads ONLY bodies)
#   5. ack on the PR
# Loop guard: only acts when the issue is NOT already actionable.

set -euo pipefail

REPO="${GITHUB_REPOSITORY:-pi-216/t-genetics}"
PR_NUMBER="${1:?usage: pr-requeue.sh <pr-number> [review-state] [comment-body-file]}"
REVIEW_STATE="${2:-}"
COMMENT_FILE="${3:-}"
PROJECT_NUMBER=2
PROJECT_OWNER="pi-216"
PROJECT_ID="PVT_kwDOE00cLc4BiTN9"
STATUS_FIELD_ID="PVTSSF_lADOE00cLc4BiTN9zhhLxrU"
TODO_OPTION_ID="f75ad846"
BLOCK_LABELS=(agent_working agent_blocked agent_needs_review)

# --- Find the linked issue via the PR body ("Closes #N") -------------------
pr_body="$(gh pr view "$PR_NUMBER" --repo "$REPO" --json body --jq .body)"
issue_number="$(printf '%s\n' "$pr_body" | grep -oE 'Closes #?[0-9]+' | grep -oE '[0-9]+' | head -1 || true)"
if [ -z "${issue_number:-}" ]; then
  echo "No linked issue (no 'Closes #N') in PR #$PR_NUMBER — nothing to re-queue."
  exit 0
fi
pr_state="$(gh pr view "$PR_NUMBER" --repo "$REPO" --json state --jq .state | tr '[:upper:]' '[:lower:]')"
if [ "$pr_state" = "merged" ]; then
  echo "PR #$PR_NUMBER is MERGED — its issue #$issue_number is already shipped; skipping re-queue."
  exit 0
fi
echo "PR #$PR_NUMBER -> issue #$issue_number"

# --- Loop guard: only act if the issue is not already actionable -----------
issue_state="$(gh issue view "$issue_number" --repo "$REPO" --json state --jq .state | tr '[:upper:]' '[:lower:]')"
has_working="$(gh issue view "$issue_number" --repo "$REPO" --json labels --jq '[.labels[].name] | index("agent_working") != null')"
if [ "$issue_state" = "open" ] && [ "$has_working" != "true" ]; then
  echo "Issue #$issue_number already open + unclaimed (actionable) — no re-queue needed."
  exit 0
fi

# --- 1. Reopen ---------------------------------------------------------------
if [ "$issue_state" != "open" ]; then
  gh issue reopen "$issue_number" --repo "$REPO"
  echo "Reopened issue #$issue_number"
else
  echo "Issue #$issue_number already open"
fi

# --- 2. Strip claim/block labels ---------------------------------------------
for label in "${BLOCK_LABELS[@]}"; do
  if gh issue view "$issue_number" --repo "$REPO" --json labels --jq "[.labels[].name] | index(\"$label\") != null" | grep -q true; then
    gh issue edit "$issue_number" --repo "$REPO" --remove-label "$label" >/dev/null
    echo "Removed label $label"
  fi
done

# --- 3. Board Status -> Todo (needs GH_PAT with project scope) ---------------
item_id="$(gh project item-list "$PROJECT_NUMBER" --owner "$PROJECT_OWNER" --limit 500 --format json 2>/dev/null \
  | python3 -c "
import json,sys
items=json.load(sys.stdin)
for it in items.get('items',[]):
    c=it.get('content') or {}
    if c.get('number')==$issue_number: print(it.get('id'))
" | head -1 || true)"
if [ -n "${item_id:-}" ]; then
  if [ -n "${GH_PAT:-}" ]; then
    GH_TOKEN="$GH_PAT" gh project item-edit --id "$item_id" --project-id "$PROJECT_ID" \
      --field-id "$STATUS_FIELD_ID" --single-select-option-id "$TODO_OPTION_ID" >/dev/null
    echo "Board Status -> Todo (item $item_id)"
  else
    echo "!! GH_PAT not set — cannot set board Status to Todo. Issue is open but NOT actionable for the worker."
  fi
else
  echo "!! No board item found for issue #$issue_number — skipped board update."
fi

# --- 4. Append review feedback to the issue body ------------------------------
if [ -n "$COMMENT_FILE" ] && [ -s "$COMMENT_FILE" ]; then
  body="$(gh issue view "$issue_number" --repo "$REPO" --json body --jq .body)"
  snippet="$(cat "$COMMENT_FILE")"
  {
    printf '%s\n' "$body"
    printf '\n---\n## Review feedback (auto re-queue, %s)\n' "$(date -u +%Y-%m-%dT%H:%MZ)"
    printf '%s\n' "$snippet"
  } > /tmp/requeue-body.md
  gh issue edit "$issue_number" --repo "$REPO" --body-file /tmp/requeue-body.md >/dev/null
  echo "Appended review feedback to issue #$issue_number body"
fi

# --- 5. Ack on the PR -----------------------------------------------------------
if [ -n "${GH_PAT:-}" ]; then
  GH_TOKEN="$GH_PAT" gh pr comment "$PR_NUMBER" --repo "$REPO" \
    --body "🔄 Re-queued issue #$issue_number — the worker will update this PR on its next tick (review feedback copied into the issue body)." >/dev/null 2>&1 \
    || GH_TOKEN="$GH_PAT" gh pr comment "$PR_NUMBER" --repo "$REPO" --body "🔄 Re-queued issue #$issue_number (review feedback copied into the issue body)." >/dev/null || true
fi
echo "Done."