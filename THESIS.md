# THESIS — TGenetics / GAaaS

> Vision artifact (Founders-Harness Day-0 pillar). Source of truth for the product contract; PRDs and pitches cite this file.

## Problem

Running genetic algorithms (GA) for real-world tuning — sales strategies, newsletter combos, donation-amount optimization, prompt/design variants — burdens the user with the evolution machinery: populations, generations, selection, breeding, history, and knowing the *right* next thing to test.

## User & value

Anyone with a fitness signal and a parameter space (engineers, ML researchers, hobbyists, teams) who wants the evolution loop operated for them — **while keeping their evaluation private on their own infra**. Value: they report one number per tested organism; we handle everything needed to create offspring worth exploring and keep the loop moving.

## What we do / what we never do (the contract — locked 2026-09-02)

- We **suggest** an organism to test (uniform random among untested; non-deterministic).
- The customer **tests it on their own infra** and reports **ONE fitness number**.
- We **breed** — average fitness from reported outcomes, roulette selection, crossover, mutation, replacement generation — and archive.
- **We never run or evaluate anyone's fitness function.**
- **We do NOT** run customer experiments/compute, do general ML, or build paid-tier features before one paying customer.

## Success metric (the gate)

**ONE paying customer** — closes the falsification gate and starts pi216 LLC revenue. Guardrail: no feature-priority work before a payer; only the tryable falsification artifact may be assembled.

## Red lines (never)

1. Never evaluate fitness for anyone (only the customer-reported `fitness_input_value`).
2. No paid-feature product build before one paying customer.
3. No external sends/spend/accounts without the founder.
4. Real-person likeness/voice in persona use-cases: off-limits; AI-disclosure on any outreach/media output.
5. Sandbox anything that executes user-supplied code.