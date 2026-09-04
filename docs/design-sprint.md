# Design Sprint — UI/brand concept → UX concept (workstream spec)

> **Status: Phase 1 LOCKED 2026-09-04 — founder ruled direction A (Lab Instrument).**
> Phase 1 artifacts live in `docs/design-sprint/ph1/` (`moodboard.html`
> deck + `skeleton-frames.html` + `DESIGN.md` token set, lint-clean; theme.css
> regenerable from DESIGN.md via designmd export). Token set is now
> normative — the apply-pass rewires `theme.css` + component classes
> mechanically when the app UI is ready. Phase 2 (UX concept) kicked off
> (see `docs/design-sprint/ph2/`). Not a PRD in the worker pipeline: design
> output is *judgment the founder rules on*, per Founders-Harness (taste
> rails lock early; only the founder encodes them). Runs as a discrete
> design agent workstream in parallel with backend build (PRDs 0001–0005
> proceed on functional styling until the brand lands).

## Why
The founder named a proper design agent for a **UI/brand concept**, then a
**UX concept**, before heavy UI build. Taste rails are a locked-early pillar:
color/type/tone/interaction chosen once, enforced mechanically (DESIGN.md →
theme.css tokens), and only the founder rules on them.

## Phase 1 — UI/brand concept (design agent, discrete sprint)
- **Inputs:** venture facts (GAaaS loop, org/billing model, "suggest → test →
  report ONE number"), t-chat's Blush Neon as a *reference for quality bar*,
  not a template, competitor-free first pass (design from the loop, not mood
  boards of rivals).
- **Output:**
  - Moodboard (2–3 directions max — e.g. "lab instrument", "clean utility",
    "warm signal") — one slide per direction, screenshots/render sketches.
  - **1 recommended direction** with rationale tied to the loop's emotional
    contract (precision, trust, "your fitness stays yours").
  - **DESIGN.md token set** for the chosen direction: color palette (hex, WCAG
    AA), type scale/families, tone words, interaction tokens (focus, hover,
    motion), spacing re: `design-md` export path.
  - Desktop + mobile skeleton frames for landing + experiment workspace (static
    HTML/CSS previews, screenshot-verified).
- **Gate → founder rules:** "go with direction X", edits (palette/tone), or
  discard. No implementation of the chosen brand before ruling.

## Phase 2 — UX concept (after brand concept ruling)
- **Flow maps:** org onboarding → invite → create chromosome → create
  experiment → get suggestion → test on own infra → report ONE fitness →
  auto-evolve → generation history. Plus the empty-state/journaling path and
  the member-vs-owner surface split.
- **Usability walkthrough:** agent-as-test-user run following the t-chat
  visual-review runbook (curl-created orgs/experiments, every flow, screenshot
  pass at 480px, findings by severity).
- **Output:** UX issue/ticket set (worker-ready bodies per the gap-analysis
  ticketing recipe) + a UX concept note (flows, decisions, open questions for
  the founder).

## Contract with the dev pipeline
- PRDs 0001–0005 build functional-but-unbranded UI (house styling tokens from
  t-chat as a stopgap, clearly labeled temporary).
- When the brand tokens land (founder-ruled), an apply-pass rewires
  `theme.css` tokens + component classes — mechanical, test-covered (designmd
  export + component specs), NOT a redesign.
- Design sprint output ships as design-only artifacts (DESIGN.md, preview
  HTML, flow maps) — never merged into the app until ruled.

## Red lines
- Real-person likeness/voice: off-limits in any brand/UX artifact.
- AI-disclosure: any generated brand/UX imagery disclosed as AI-generated.
- No vendor spend: self-hosted fonts/assets; no paid design tooling accounts.
- The brand must not promise paid-tier features (red line until first payer).

## Definition of done (Phase 1)
- 2–3 directions + 1 recommendation + DESIGN.md token set + skeleton previews,
  all reviewed and founder-ruled → token set locked into the repo (DESIGN.md
  + theme.css export) with `design-md` lint green.
- Phase 2 (UX) kicks off only after the Phase 1 ruling.