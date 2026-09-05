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

## UX decisions (founder-ruled 2026-09-04)

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
- **The loop is decoupled, not auto-stepped.** Request a suggestion → show it →
  report the outcome WHEN it returns (minutes, hours, or a high-volume day
  later). There is NO auto-suggest of the next organism after a report; the
  customer pulls the next suggestion when they want it. (Founder, Q2.)
  Canonical use case: **tip-amount suggestions on a payment form** — a
  payment processor shows many forms to many customers all day; each form can
  request a suggestion and present it, and the outcome (converted /
  no-converted) is reported back later, decoupled and batched. The UI/API
  treats a suggestion as a long-lived object with its own lifecycle
  (suggested → shown → outcome), not a transient "next step."
- **Generation history is a table** for now (mono data, parent columns);
  lineage/tree view deferrable until analytics demand it. (Founder, Q1.)
- **Onboarding is a one-page flat invite flow** — single form (email + role),
  no wizard; flat roles make multi-step unwarranted. (Founder, Q3.)

## Suggestion semantics (founder, 2026-09-04)

- **Suggestions are NON-deterministic.** Requesting a suggestion must not
  produce a predictable / always-the-same organism. The customer cannot
  game the loop by re-requesting until they get a desired organism, and no
  organism is starved of exposure by a deterministic queue.
- **Randomize among the UNTESTED pool.** The suggestion pool is the
  organisms in the current generation that do NOT yet have a reported
  fitness value. Every suggestion is a uniform random draw from that pool.
  An organism that has already been reported (has a fitness value) is
  never suggested again within the generation — when every organism has a
  reported fitness, the generation is ripe for evolution and a fresh
  untested pool is born. (This replaces the v1 "least-logged-first"
  behavior, which biased exposure toward the untested in queue order.)
- **Already-suggested-but-unreported = still in the pool.** An organism
  that was suggested but whose outcome hasn't come back yet has no fitness
  value, so it stays suggestable (drawing it again just samples it more —
  fine for the payment-form use case, where many customers each get a
  presentation). A customer cannot game this: the draw is random, and
  re-requesting never returns a *known-fitness* organism to exploit.
- **Equal opportunity to be tested.** Because every organism without a
  fitness value has an equal chance to be the next suggestion, survival is
  determined only by the fitness function, never by luck of exposure
  (seasonal / time-of-day effects don't masquerade as fitness).
- **Exploit mode = PAID TIER, deferred.** An opt-in knob where the customer
  says "X% of the time give me the strongest known organism" (to smooth
  seasonal/time-of-day bias) is exactly the exploitation/greed control that
  AGENTS.md defers until the first paying customer. Design intent noted so
  the suggestion API can grow a sampling-mode parameter later; NOT built
  pre-payer. Red line.
- **Outcome timing is unbounded and the customer's problem.** We never run
  their fitness function; the gap between "shown a suggestion" and "they
  report the outcome" can be days or weeks (e.g. a suggestion is a
  training recipe and training takes weeks). Suggestions are long-lived
  objects; the engine never awaits a result and never blocks the pool on a
  pending outcome.

## Open UX questions (founder)

**All founder-ruled 2026-09-04 (Q1 table, Q2 decoupled two-step, Q3 flat).
Remaining open for later:**

- **Q4 Suggestion lifecycle in the API:** explicit status transitions
  (suggested → shown → outcome) so a long-lived suggestion can be queried
  and re-presented across sessions without losing state? (Recommend: yes —
  supports the payment-form use case; the token API already returns one
  suggestion, add a lightweight "current suggestion" read.)
- **Q5 Outcome batching:** high-volume customers report outcomes in batches
  (a day's worth at once). Should the report endpoint accept a list, or is
  one-at-a-time with a batch client loop fine? (Recommend: keep
  one-at-a-time — the API loop is trivial; adds no protocol surface.)

## Part B — usability walkthrough (queued)

Once PRD-0003/0004 UI is merged and running, run the t-chat visual-review
runbook: curl-created orgs/experiments, every flow, screenshot pass at 480px,
findings by severity → UX ticket set (worker-ready bodies). Until then this
note is the UX contract.