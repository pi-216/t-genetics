# FOUNDERS — pillar index

Each pillar: **Lock / Enforcement / Red line**. Status-tagged:
`#harness/status/locked` · `in-review` · `rebuilding`. Keep it living.

| Pillar | Lock | Enforcement | Red line | Status |
|---|---|---|---|---|
| Thesis & constraints | THESIS.md (contract locked 2026-09-02) | every PRD/pitch cites it | never evaluate anyone's fitness function | `#harness/status/locked` |
| Architecture rails | GLCommand command pattern + packwerk packs + HAML/ViewComponent + Turbo | packwerk check + `bin/verify` Tier-0 gate (rubocop · brakeman · bundler-audit · packwerk · erb_lint · rspec · cucumber · rswag:verify · gherkin_lint) | no cross-pack refs without declared `dependencies:` | `#harness/status/locked` |
| Contract spine | schema + command/event contracts + org-scoped ownership rails | strong_migrations at migrate time + rswag:verify (swagger regenerated, never hand-edited) | no schema edits by hand; cross-org access returns 403/404, never data | `#harness/status/locked` |
| Agent governance | AGENTS.md hub → board/tickets/PR gate ('approved' label = release switch) | CI gates (lint/test/scan_js/scan_ruby) + pr-conventions-gate before any PR | never `gh pr create` directly without the gate | `#harness/status/locked` |
| Observability | Sentry pillar (docs/ops/sentry.md): SDK + env tagging, releases, cron check-ins, triage | pillar minimum install + `bin/sentry_checkin` on agent crons | — | `#harness/status/in-review` |
| Identity & legal | entity, domain, naming; flat owner/member roles per org | request specs + Pundit authz on every action | no granular permissions, ever; no real-person likeness/voice | `#harness/status/in-review` |
