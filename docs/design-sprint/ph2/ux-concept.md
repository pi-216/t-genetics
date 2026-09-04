# Phase 2 — UX Concept (workstream note)

> **Status: kicked off 2026-09-04 (after Phase 1 ruling → direction A).
> Part A (flow maps + UX decisions + open questions) is drafted here.
> Part B (usability walkthrough as agent-as-test-user) runs once the
> workspace UI ships — the worker is still building PRD-0003
> (experiment workspace) and PRD-0004 (chromosome designer) waves; a
> walkthrough needs running screens, not PRDs.

## Flow maps (the loop, end to end)

```
org onboarding → invite members → create chromosome → create experiment
  → get suggestion → test on own infra → report ONE fitness
  → auto-evolve (ripe) → new generation → generation history
```

**Surface split by role (flat owner/member only):**

| Step | Owner | Member |
|---|---|---|
| Create org / invite | ✅ | — |
| Manage members / API tokens | ✅ | — |
| Create chromosome | ✅ | ✅ |
| Create experiment | ✅ | ✅ |
| Request suggestion | ✅ | ✅ |
| Report outcome | ✅ | ✅ |
| Trigger/evolve generation | ✅ (auto when ripe) | ✅ |

**Primary loop screens (map against PRD-0003/0004):**
1. **Chromosome designer** (PRD-0004) — typed alleles (Float/Integer/Boolean/
   Option), inline bounds validation, live preview of a generated organism.
2. **Experiment workspace** (PRD-0003) — create experiment (chromosome +
   population size), browse generations, blank/empty states before any
   outcome exists.
3. **Suggestion + report** — RequestSuggestion returns ONE organism;
   RecordOutcome takes ONE fitness number. UI = "here's what to test" →
   "what came back" (one field, one submit).
4. **Generation browser** — lineage, parent pairs, per-organism typed values.
5. **API tokens** (PRD-0005) — owner-only; machine access path mirrors the
   same loop via `Authorization: Bearer`.

## UX decisions (proposed, founder can overrule)

- **The ONE number is a first-class object.** Report screens show a single
  prominent numeric input + submit; no multi-metric forms (red line:
  `fitness_input_value` is the only fitness-bearing input).
- **Empty states are explicit.** A generation with no reported outcomes shows
  "no fitness recorded yet" (per PRD-0004 empty-state ticket), never a hollow
  zero.
- **Members act, owners administer.** Surface split above; no per-feature
  permission UI (flat roles only — no granular permissions, ever).
- **Machine-first and human-first share the loop.** Token API (PRD-0005) and
  the UI both hit the same commands; UI hides token plumbing.
- **No paid-tier affordances on surfaces** until first payer (red line).

## Open UX questions (founder)

- **Q1 Timeline viz:** generation history as a lineage/tree view (direction C
  showed cards), or a table? Direction A default: table with parent columns,
  tree later if analytics demand it.
- **Q2 Suggestion moment:** after "report outcome," does the UI auto-suggest
  the next organism, or return to the generation view with a banner?
  (Recommend: auto-suggest next — keeps the loop moving.)
- **Q3 Onboarding depth:** one-page invite flow (email + role) vs multi-step?
  (Recommend: one page — flat roles make it a single form.)

## Part B — usability walkthrough (queued)

Once PRD-0003/0004 UI is merged and running, run the t-chat visual-review
runbook: curl-created orgs/experiments, every flow, screenshot pass at 480px,
findings by severity → UX ticket set (worker-ready bodies). Until then this
note is the UX contract.