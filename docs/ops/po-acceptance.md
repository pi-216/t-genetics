# PO acceptance gate — t-genetics (GAaaS engine)

The **browser-truth** loop that closes the gap request-layer gates cannot see.
`bin/verify` + CI assert request-truth; they pass while a feature is broken in
a real browser (2026-09-10: the chromosome designer shipped green while Turbo
swallowed Add-allele and validation feedback — findings T1/T2). After every
PRD epic completes, this gate walks the feature in a real browser and turns
deviations into Finding tickets before the founder sees the result.

Issue #152 owns this gate. `venture-agent-harness` and `founders-harness`
carry the DoD→gate house rule (every PRD DoD line maps to an enforced gate;
unenforceable lines get deleted at review).

## Architecture

```
board (Project 2) ──▶ scripts/tgenetics_po_state.sh (monitor, profile-side)
                        └─ phase token (deterministic; identical output = skip)
                              OPEN:PO_READY:<PRD-tags>  — complete WITHOUT pass
                              OPEN:PO_NONE              — quiet queue (a result)
                              OPEN:UNKNOWN              — fail-closed, wake once
                                   │ (cron fires ONLY when the token changes)
                                   ▼
                        gaas-po-acceptance cron (PAUSED until founder go)
                            │ boots/uses the live app (tgenetics.pi216.ai),
                            │ walks the PRD's @javascript scenarios AS the walk
                            │ script (capybara-screenshot evidence), walks each
                            │ acceptance criterion as a user
                            ▼
                 per-PRD verdict → MVP.md / Vision Review (shipped|verified|partial)
                 deviations  → Finding tickets (canonical format, NOT approved)
                 pass → PRD tag appended to the pass book (idempotency boundary)
```

The PO agent **never fixes in-repo** (founder ruling 2026-09-04) — deviations
become Finding tickets with `needs-founder` so the morning brief surfaces them.
Findings are never auto-approved; the founder rules on each.

## Monitor contract

Canonical: `.github/scripts/po-acceptance-state.sh` (this repo), installed into
the gaas profile as `scripts/tgenetics_po_state.sh` for the cron's monitor gate.

- **PRD set** = epics (issues titled `[PRD] PRD-XXXX …`); tag = `PRD-XXXX`
  (strict `^PRD-[0-9]+$` — titles are user-controlled and may not reach the
  token otherwise).
- **Children** = issues titled `[PRD-XXXX] …` carrying BOTH `approved` and
  `ticket` labels (findings/process items are titled differently by design).
- **Ready** = children all closed AND no pass recorded for the PRD.
- **Tokens** — `OPEN:PO_READY:<PRD-tag[,PRD-tag...]>` (sorted, unique;
  process the FIRST tag per tick, then record its pass — the token then
  changes to the next tag, one bounded walk per firing) · `OPEN:PO_NONE` ·
  `OPEN:UNKNOWN`.
- **Pass book** — JSON array of passed PRD tags, default
  `~/.hermes/profiles/gaas/state/tgenetics_po_passes.json`; a malformed book is
  `OPEN:UNKNOWN`. A PO pass must NEVER fire on unknown state.
- **Env overrides** (tests use them): `TGEN_PO_REPO`, `TGEN_PO_REPO_DIR`
  (Sentry heartbeat checkout), `TGEN_PO_PASS_BOOK`, `TGEN_PO_GH`.
- **Sentry heartbeat** — presence check-in for `gaas-po-acceptance` on every
  tick (mirrors `scripts/tgenetics_queue_state.sh`); no checkout → no-op.

Regression suite: `.github/scripts/test-po-acceptance-state.sh` — stub-gh
fixtures, sabotage-verified, run in the CI lint job. Full contract table:

| Scenario | Token |
|---|---|
| Every approved+ticket child of an epic closed, no pass | `OPEN:PO_READY:PRD-XXXX` |
| Multiple ready epics | sorted, comma-joined, unique |
| Nothing ready / no epics / unapproved children / open child | `OPEN:PO_NONE` |
| Pass book already holds the PRD | `OPEN:PO_NONE` (exactly one pass) |
| gh outage / gh garbage / malformed pass book / jq missing | `OPEN:UNKNOWN` |

## Walk procedure (the cron's job when it fires)

1. Read the PRD's feature spec (`gherkin_specs/`) — the DoD lives there.
2. Boot/use the live app (`https://tgenetics.pi216.ai`; local `:3005` for dev).
   Authenticate as the venture owner; drive the feature end-to-end as a user
   (signup → chromosome → experiment → suggestion → outcome where applicable).
3. Execute the PRD's `@javascript` scenarios AS the walk script — real browser,
   capybara-screenshot captures evidence per step. Do not stop at green:
   walk each acceptance criterion as a user and eyeball the rendered result.
4. Every deviation → a Finding ticket in the canonical format:

   ```
   ## Observed
   <date, live walk, session context> — what actually happened (screenshots).
   ## Expected
   <what the PRD/DoD line or the feature spec promises>
   ## Root cause
   <when found — never guess; leave "not determined" otherwise>
   ## Fix direction
   <concrete change suggestion for the worker>
   ## Acceptance criteria
   - <testable criteria the fix must satisfy>
   ---
   **NOT approved — founder ruling required.** Finding tickets are never
   auto-approved; the founder rules on them (fix + approve, defer, or close).
   ```
   Labels: `ticket` + `needs-founder` (morning-brief surfacing). Never
   `approved`.
5. Record the verdict in `MVP.md` / Vision Review: `shipped | verified |
   partial` (`verified` = PO pass done).
6. Append the PRD tag to the pass book (`jq '. + ["PRD-XXXX"]'`) — the next
   monitor tick then moves to the next ready PRD, or `PO_NONE`.

## Cron wiring (founder go required — not yet given)

The cron is **PAUSED until the founder says go** (issue #152). When enabled:

```bash
# profile gaas
hermes cron create gaas-po-acceptance \
  --schedule '0 8 * * *' \
  --monitor-script tgenetics_po_state.sh \
  --skills github-issues,obsidian-daily-note-enrichment,venture-vision-review \
  --workdir /home/tim/source/activity/t-genetics \
  --deliver local
hermes cron pause gaas-po-acceptance   # stays paused until founder go
```

The cron prompt must call `bin/sentry_checkin gaas-po-acceptance start` at run
start and `ok|failed` at completion (workdir = repo), and MUST `[SILENT]` when
the token is `OPEN:PO_NONE` (a quiet queue is a result, not a failure).

## Sentry provisioning (one-time, needs founder OK — external write)

Follow `docs/ops/sentry.md`; the monitor slug is `gaas-po-acceptance`
(expected interval = the cron schedule). API/envelope-created monitors land
`ObjectStatus=disabled` on this org and DROP check-ins until enabled once in
the Sentry UI (Crons → monitor → enable) — enable it after the first
`bin/sentry_checkin gaas-po-acceptance ok` (which the monitor script already
sends on every tick). A silently-paused cron then fires the missing-tick alert
instead of rotting.

## When to touch this file

- New PRD epic added → no change (the monitor derives the PRD set from the
  board).
- Cron schedule change → update Sentry expected interval + this runbook.
- The walk procedure grows a new evidence type → document it here.