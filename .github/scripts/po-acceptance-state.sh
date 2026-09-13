#!/usr/bin/env bash
# po-acceptance-state.sh — monitor gate for the <venture>-po-acceptance cron.
#
# Watches PRD epics on the t-genetics board (pi-216 org project 2): when every
# `approved`+`ticket` issue of a PRD epic is merged (closed — the worker's PR
# auto-closes the issue) and no PO pass is recorded for that PRD, the phase
# token flips so the PO acceptance agent wakes and walks the feature in a real
# browser (issue #152; full design in docs/ops/po-acceptance.md).
#
# This file is the canonical instance, regression-tested by
# test-po-acceptance-state.sh (CI lint job) and installed into the gaas
# profile as scripts/tgenetics_po_state.sh for the cron's monitor gate.
#
# Emits a DETERMINISTIC phase token (contract: no timestamps, identical output
# = skip the tick). Tokens:
#   OPEN:PO_READY:<PRD-tag[,PRD-tag...]>  — complete-without-pass epics, sorted
#       (process the FIRST tag per tick, then record its pass — the token then
#       changes to the next tag, driving one bounded walk per firing)
#   OPEN:PO_NONE   — no complete-without-pass PRD (a quiet queue is a result)
#   OPEN:UNKNOWN   — gh/jq unavailable, gh output unparseable, or pass book
#       malformed: wake once, the agent reports — a PO pass must NEVER fire on
#       unknown state (fail-closed, genome principle: zero results are explicit)
#
# PRD set = epics (issues titled "[PRD] PRD-XXXX …"), tag = "PRD-XXXX".
# Children = issues titled "[PRD-XXXX] …" carrying BOTH `approved` and
# `ticket` labels (findings/process items are titled differently by design).
#
# Env overrides (tests use them; the cron runs with defaults):
#   TGEN_PO_REPO       repo slug (default pi-216/t-genetics)
#   TGEN_PO_REPO_DIR   repo checkout for the Sentry heartbeat
#                      (default: this script's repo root — walk up from
#                      .github/scripts/)
#   TGEN_PO_PASS_BOOK  pass-book JSON path — array of PRD tags with a recorded
#                      pass (default: the gaas profile's state dir — this
#                      repo's PO pass book lives with its venture profile)
#   TGEN_PO_GH         gh binary (default gh)
#
# Requires gh (auth'd) + jq. Dependencies documented in docs/ops/po-acceptance.md.
# Note: --limit 1000 caps the issue scan; bump it if the repo ever approaches
# ~1000 total issues (a truncated scan could hide a ready PRD as PO_NONE).
#
# Sentry heartbeat (Sentry pillar): presence check-in for the
# gaas-po-acceptance monitor, mirroring scripts/tgenetics_queue_state.sh — the
# monitor script runs even when the agent is gated quiet, so a silently-paused
# cron fires the missing-tick alert instead of rotting. No checkout -> no-op.
set -u
export LC_ALL=C

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

REPO="${TGEN_PO_REPO:-pi-216/t-genetics}"
REPO_DIR="${TGEN_PO_REPO_DIR:-$REPO_ROOT}"
PASS_BOOK="${TGEN_PO_PASS_BOOK:-$HOME/.hermes/profiles/gaas/state/tgenetics_po_passes.json}"
GH_BIN="${TGEN_PO_GH:-gh}"

if [ -x "$REPO_DIR/bin/sentry_checkin" ]; then
  (cd "$REPO_DIR" && bin/sentry_checkin gaas-po-acceptance ok >/dev/null 2>&1) || true
fi

command -v jq >/dev/null 2>&1 || { echo "OPEN:UNKNOWN"; exit 0; }

data=$("$GH_BIN" issue list --repo "$REPO" --state all --limit 1000 --json number,title,state,labels 2>/dev/null) \
  || { echo "OPEN:UNKNOWN"; exit 0; }
[ -n "$data" ] || { echo "OPEN:UNKNOWN"; exit 0; }
printf '%s' "$data" | jq -e 'type == "array"' >/dev/null 2>&1 || { echo "OPEN:UNKNOWN"; exit 0; }

pass_data="[]"
if [ -f "$PASS_BOOK" ]; then
  pass_data=$(cat "$PASS_BOOK" 2>/dev/null) || { echo "OPEN:UNKNOWN"; exit 0; }
  printf '%s' "$pass_data" | jq -e 'type == "array"' >/dev/null 2>&1 || { echo "OPEN:UNKNOWN"; exit 0; }
fi

has_pass() {
  printf '%s' "$pass_data" | jq -e --arg t "$1" 'index($t)' >/dev/null 2>&1
}

epic_tags=$(printf '%s' "$data" \
  | jq -r '.[] | select(.title | startswith("[PRD] ")) | (.title | gsub("^\\[PRD\\] "; "") | split(" ") | .[0])' 2>/dev/null) \
  || { echo "OPEN:UNKNOWN"; exit 0; }

ready=""
if [ -n "$epic_tags" ]; then
  while IFS= read -r tag; do
    [ -n "$tag" ] || continue
    # titles are user-controlled: only PRD-XXXX tags may reach the token, or
    # $ready's unquoted expansion would glob-expand arbitrary title tokens
    [[ "$tag" =~ ^PRD-[0-9]+$ ]] || continue
    has_pass "$tag" && continue
    children=$(printf '%s' "$data" | jq -c --arg p "[$tag]" \
      '[.[] | select((.title | startswith($p)) and any(.labels[]; .name == "approved") and any(.labels[]; .name == "ticket"))]')
    [ "$(printf '%s' "$children" | jq 'length')" != "0" ] || continue
    [ "$(printf '%s' "$children" | jq '[.[] | select(.state == "open")] | length')" = "0" ] || continue
    ready="$ready $tag"
  done <<< "$epic_tags"
fi

if [ -z "$ready" ]; then
  echo "OPEN:PO_NONE"
else
  token=$(printf '%s\n' $ready | sort -u | paste -sd, -)
  echo "OPEN:PO_READY:$token"
fi