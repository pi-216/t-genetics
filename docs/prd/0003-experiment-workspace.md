# PRD-0003 — Experiment workspace (the loop, in the UI)

## Summary
The web UI for the core product loop, built on the existing
`packs/experiments` engine: create an experiment (pick a chromosome +
population size) → get a suggestion (an organism to test) → test it on your
own infra against your fitness → report **ONE** fitness number back → when the
experiment is "ripe," it breeds the next generation automatically → browse
generation history. The customer's fitness function is never touched by us.

## Problem / motivation
The engine commands (`Experiments::RequestSuggestion`, `RecordOutcome`,
`EvaluateAndEvolve`) already implement the loop — but there is no human
surface to drive it. The commercial product is the loop, and until a customer
can create an experiment, receive a suggestion, and record a result in a
browser, the trial artifact cannot be falsified.

## Goals / Non-goals
- Goals: experiment CRUD (org-scoped), suggestion workflow, fitness reporting,
  auto-evolution with a "ripe" indicator, generation history view.
- Non-goals (Out): exploitation/greed controls (paid tier — red line until
  first payer), generation-progress visualizations beyond a basic history list
  (paid tier), experiment archiving, sharing experiments across orgs, custom
  fitness-function integration (never — red line), batch/automated reporting
  (that's the API's job, PRD-0005).

## Scope — In / Out
**In:** experiment index (org-scoped); create (name, chromosome select,
population size); show: current generation, suggestion action, performance log
list; "get suggestion" → creates a PerformanceLog and shows the organism's
values; "report outcome" → one fitness number per suggestion (with edit/retry);
"ripe for evolution" indicator + auto-evolve on next suggestion/report when
ripe; generation history list (generation id, organism count, avg fitness).
**Out:** everything under Non-goals.

## Acceptance criteria
- A member can create an experiment under their org; another org cannot see it.
- "Get suggestion" returns an organism from the current generation and records
  a PerformanceLog entry.
- "Report outcome" records exactly one fitness number against that suggestion.
- When `ripe_for_evolution?` (existing thresholds), the next loop action
  triggers `EvaluateAndEvolve` → new generation created; history reflects it.
- A user can browse past generations and see per-organism values + recorded
  fitness.
- All mutations go through the existing `Experiments::*` commands (no new
  business logic in controllers).
- Spec'd via request specs + BDD; `bin/verify` green.

## Edge cases & red lines
- We never evaluate fitness: the only fitness-bearing input is the customer's
  reported number (stored as `fitness_input_value` on the PerformanceLog).
- Reporting a fitness for an already-recorded suggestion — allow re-report
  (update) with history, or block? (Open question A2.)
- Empty generation / no suggestions when population exhausted → surfaced as an
  explicit empty state, never silent.
- Evolution must be idempotent — a double-fire must not create two generations.
- Org scoping enforced on every query (cross-org 403/404).

## Metrics / definition of done
- Request + command specs green; BDD green; `bin/verify` green.
- A full loop walkthrough (create → suggest → report → evolve → history) works
  end-to-end in the dev server (agent walkthrough per the visual-review runbook).
- No fitness evaluation code path exists anywhere in the product.

## Open questions (product owner)
- **A1 Ripe indicator semantics:** show "ready to evolve" as a badge/label only
  (recommend), or add an explicit "Evolve now" button for owners?
  (Recommend badge-only for v1 — evolution stays automatic.)
- **A2 Re-reporting:** allow correcting a fitness value after recording
  (recommend yes, with an audit trail on the log) or immutable?
- **A3 Population size / thresholds:** expose them as experiment config at
  creation (recommend yes — they already exist on the model).

## Related
- PRD-0004 (chromosome designer + visual generation browser) — sibling UI.
- PRD-0005 (API) — the same loop over HTTP for machines.