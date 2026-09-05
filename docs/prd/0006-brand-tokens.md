# PRD-0006 — Lab Instrument brand tokens apply-pass

## Summary

Apply the **locked** Lab Instrument brand tokens (founder-ruled 2026-09-04,
direction A, design-sprint Phase 1) to the running application. The normative
source of truth is `docs/design-sprint/ph1/DESIGN.md`. This is a **mechanical
restyle** — no redesign, no new UX, no copy changes beyond token-driven
styling. It replaces the stock Rails scaffold look (teal body, indigo primary,
coral/ochre Tailwind palette) with the dark calibrated workbench: `base`
`#0B0F14` surfaces, amber `signal` `#F5B64A` as the sole interaction driver,
monospace tabular numerals for every datum.

## Problem / motivation

The lock landed on 2026-09-04 but nothing in the app consumes it: the shared
layout still hardcodes `bg-teal-900.text-teal-300`, the primary CTA is the
stock `bg-indigo-600`, `application.tailwind.css` still ships the untouched
Rails default coral/ochre/olive palette, and the landing page carries an
explicit drift flag ("brand tokens land later as a restyle"). Visitors to
`tgenetics.pi216.ai` see an unbranded scaffold. The product promise ("your
fitness stays yours") has no visual identity until the instrument look ships.

## Goals / Non-goals

- Goals: wire DESIGN.md tokens into the theme layer; restyle the shared
  layout, landing page, and existing workspace surfaces (chromosome /
  experiment / organism views and ViewComponents) to the component spec;
  make the restyle verifiable (token parity + visual assertions).
- Non-goals (Out): redesign, layout rework, copy changes, new components,
  paid-tier presentation, fonts/CDN additions, UX-concept work (that is
  Phase 2, `docs/design-sprint/ph2/ux-concept.md`).

## Scope — In / Out

**In:**
- Theme layer: derive `theme.css` (Tailwind v4 `@theme`) mechanically from
  DESIGN.md via the design-md CLI; `designmd lint` green; token parity test.
- `config/tailwind.config.js` / `application.tailwind.css` rewire to the
  brand token set (base/surface/raised/line/signal/good/danger/ink/inkMuted/
  onSignal, data/data-lg mono faces, 4/6/10 radii).
- Shared layout: dark base background, ink text, hairline 1px borders,
  mono defaults — no teal/indigo scaffold classes anywhere.
- Landing page: hero (display type on dark), amber primary CTA
  (`button-primary`), section kickers in signal, data numerals in mono.
- Existing workspace views/components (chromosome, experiment, organism,
  fitness trend, page header): card/stat-value/nav/table-row-hot token
  treatment; every number renders mono tabular (`tnum`).
- BDD: executable scenarios per surface (layout, landing, data numerals,
  token parity).

**Out:** everything under Non-goals. No `theme.css` drift from DESIGN.md;
the file is generated, not hand-edited, and re-exported when the tokens
change.

## Acceptance criteria

- `theme.css` matches DESIGN.md tokens exactly (parity test in spec);
  `npx -y @google/design.md lint docs/design-sprint/ph1/DESIGN.md` exits 0.
- Body/layout renders on `base` (`#0B0F14`) with `ink` (`#E6EDF3`) text —
  no `bg-teal-*`/`text-teal-*`/stock scaffold classes in any rendered page.
- Primary CTA renders `button-primary`: `signal` (`#F5B64A`) fill, `onSignal`
  (`#1A1205`) text, 6px radius — one amber action per surface.
- Every numeric datum (fitness, ids, generation counts, stats) renders in a
  monospace face with tabular numerals (data/data-lg tokens).
- No stock Rails default palette classes (`coral-*`, `ochre-*`, `olive-*`,
  `indigo-*`, default `teal-*`) remain in app styles or views.
- `bin/verify` green; BDD green; component specs cover the brand classes.

## Edge cases & red lines

- Restyle only — no behavior/UX change; all existing specs stay green
  (content/links/routes untouched).
- No paid-tier feature claims anywhere (red line until first payer).
- No real-person likeness/voice; no AI-generated imagery on the page.
- No gradients, glassmorphism, glow, or pill radii (DESIGN.md Do/Don'ts).
- Side effects after DB commit; packwerk boundaries respected (styling only,
  no new packs expected).
- If DESIGN.md tokens change, `theme.css` must be re-exported — never
  hand-edit generated output.

## Metrics / definition of done

- Token parity spec green; `designmd lint` exit 0.
- Request/component specs green; BDD green; `bin/verify` green.
- Visual pass on landing + one authed workspace page (headless Chrome)
  shows dark base, amber CTA, mono data numerals.
- PR(s) merged to main; auto-merge policy applies after CI.

## Decisions (founder rulings)

- **Locked 2026-09-04:** direction A "Lab Instrument"; DESIGN.md normative;
  apply-pass rewires theme.css + component classes mechanically, test-covered,
  NOT a redesign (design-sprint contract).
- **Source of truth:** `docs/design-sprint/ph1/DESIGN.md` — generated
  `theme.css` must not drift from it.

## Related

- `docs/design-sprint/ph1/DESIGN.md` (normative tokens — read it first).
- `docs/design-sprint.md` (apply-pass contract, §Design sprint).
- PRD-0001 (landing — first brand surface; its drift flag is resolved here).
- PRD-0003/0004 workspace pages (surfaces being restyled).
- Phase 2 UX concept (`docs/design-sprint/ph2/ux-concept.md`) — NOT in scope.