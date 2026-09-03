# PRD-0004 — Graphical chromosome designer & generation browser

## Summary
The visual surface for chromosomes: a **designer** to build a chromosome from
alleles (float/int/bool/option — ranges, bounds, choices) with a live preview,
plus a **generation browser** showing organisms and their values, with a basic
fitness chart. This is the "graphical interface for chromosomes" the founder
named as a launch minimum. The existing CRUD (index/new/edit/show via
ViewComponents) is the base; this PRD upgrades it into a first-class designer
and adds the experiment-side visual browser.

## Problem / motivation
Chromosomes are the substrate of everything, but today they're plain
forms/tables. A customer needs to *see* their genome structure at a glance —
alleles, types, ranges — and watch generations progress. Without a visual
surface, the product reads as a developer tool, not a service non-engineers
can drive.

## Goals / Non-goals
- Goals: visual chromosome designer (allele cards, type-aware inputs, live
  validation), organism value viewer, generation browser with a simple fitness
  trend chart.
- Non-goals (Out): drag-and-drop allele ordering (defer), chromosome versioning/
  diffing, CSV/JSON export/import (the API covers machine access), paid-tier
  visualization depth (generation-progress insights — red line until first
  payer), mobile redesign (responsive on desktop-first; mobile pass later).

## Scope — In / Out
**In:** chromosome designer page (replace/extend the existing index/new/edit —
allele cards with type picker: Float/Integer/Boolean/Option; range/choice
inputs; inline validation errors; live preview of the allele set); organism
value viewer (per-organism values rendered by allele type); generation browser
(generations list → organisms → values → recorded fitness); simple fitness
trend chart (per-generation average fitness line — local chart, no external
charting CDN, see Edge cases).
**Out:** everything under Non-goals.

## Acceptance criteria
- A user can create a chromosome with mixed allele types and see a live preview.
- Allele validation (e.g. min ≤ max, option list non-empty) is inline and clear.
- From an experiment, a user can browse generations and open an organism to see
  its typed values.
- A per-generation fitness trend renders from recorded fitness values (empty
  state when no fitness recorded yet).
- Owned largely by existing `app/components` (ChromosomeComponent +
  additions); no new heavy JS framework; Hotwire/Turbo where interaction is
  needed.
- Spec'd via request specs + BDD; `bin/verify` green.

## Edge cases & red lines
- No external charting library/CDN without vendor approval (dependency +
  network policy — self-host or `inline_svg`/CSS bars first).
- No real-person likeness/voice anywhere.
- Chromosome/allele validation matches server-side rules exactly (UI never
  bypasses model validation).
- Org scoping enforced on all chromosome routes (cross-org 403/404).
- Designer mutations go through commands (existing chromosome/allele commands
  or thin new ones) — no direct model writes in controllers.

## Metrics / definition of done
- Request + component + model specs green; BDD green; `bin/verify` green.
- Designer walkthrough (create mixed chromosome → edit → validate → use in
  experiment) passes the agent visual walkthrough.
- No new JS framework added; chart is dependency-light or pure CSS/SVG.

## Open questions (product owner)
- **A1 Designer layout:** single-page form with allele card list (recommend —
  simplest) vs. two-pane (list + preview side-by-side)?
- **A2 Chart library:** tiny self-hosted SVG/CSS trend (recommend for v1) vs.
  add a chart gem? (Dependency approval needed.)
- **A3 Existing CRUD:** fully replace the current chromosome views with the
  designer (recommend — single surface) or keep both?

## Related
- PRD-0003 (experiment workspace) — the generation browser lives there;
  this PRD is the chromosome-side surface.
- PRD-0005 (API) — machines CRUD chromosomes via token; the designer is the
  human route to the same data.