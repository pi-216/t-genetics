---
version: alpha
name: GAaaS Lab Instrument
description: Dark calibrated workbench for a genetic-algorithm engine — precision instrument aesthetic, amber signal thread, mono numerals for data. Draft for founder ruling (design-sprint Phase 1, direction A); not to be implemented until ruled.
colors:
  primary: "#F5B64A"
  base: "#0B0F14"
  surface: "#11161D"
  raised: "#1A212B"
  line: "#232C38"
  signal: "#F5B64A"
  good: "#4ADE80"
  danger: "#FF5D5D"
  ink: "#E6EDF3"
  inkMuted: "#8A97A8"
  onSignal: "#1A1205"
  surfaceHot: "#1B1F18"
typography:
  display:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: 3rem
    fontWeight: 700
    lineHeight: 1.05
    letterSpacing: "-0.02em"
  headline:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: 1.5rem
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.015em"
  body-lg:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: 1.0625rem
    fontWeight: 400
    lineHeight: 1.5
  body-md:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: 0.9375rem
    fontWeight: 400
    lineHeight: 1.5
  data:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: 0.9375rem
    fontWeight: 600
    lineHeight: 1.4
    fontFeature: "tnum"
  data-lg:
    fontFamily: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: 2.25rem
    fontWeight: 700
    lineHeight: 1.1
    fontFeature: "tnum"
  caption:
    fontFamily: "Inter, system-ui, sans-serif"
    fontSize: 0.8125rem
    fontWeight: 500
    lineHeight: 1.4
    letterSpacing: "0.08em"
rounded:
  sm: 4px
  md: 6px
  lg: 10px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  reach: 44px
components:
  button-primary:
    backgroundColor: "{colors.signal}"
    textColor: "{colors.onSignal}"
    typography: "{typography.caption}"
    rounded: "{rounded.md}"
    padding: 12px 22px
  button-primary-hover:
    backgroundColor: "#F7C468"
    textColor: "{colors.onSignal}"
    rounded: "{rounded.md}"
    padding: 12px 22px
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.caption}"
    rounded: "{rounded.md}"
    padding: 11px 21px
  button-secondary-hover:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 11px 21px
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 11px 16px
  input-focus:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.md}"
    padding: 11px 16px
  card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.lg}"
    padding: 16px
  stat-value:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.signal}"
    typography: "{typography.data-lg}"
    rounded: "{rounded.lg}"
    padding: 14px 16px
  stat-value-good:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.good}"
    typography: "{typography.data-lg}"
    rounded: "{rounded.lg}"
    padding: 14px 16px
  table-row-hot:
    backgroundColor: "{colors.surfaceHot}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    padding: 10px 16px
  text-danger:
    textColor: "{colors.danger}"
  nav-item:
    textColor: "{colors.inkMuted}"
    typography: "{typography.body-md}"
    padding: 8px 12px
    rounded: "{rounded.sm}"
  nav-item-active:
    backgroundColor: "{colors.raised}"
    textColor: "{colors.ink}"
    typography: "{typography.body-md}"
    rounded: "{rounded.sm}"
    padding: 8px 12px
  kicker:
    textColor: "{colors.signal}"
    typography: "{typography.caption}"
  app-background:
    backgroundColor: "{colors.base}"
  hairline:
    backgroundColor: "{colors.line}"
---

# GAaaS — Lab Instrument

## Overview

A dark, calibrated workbench for a genetic-algorithm engine. The visual metaphor
is the laboratory instrument: quiet, precise, dense-but-ordered, and honest
about measurement. The amber signal is the single driver of interaction — it is
where the loop feels alive. Monospace numerals carry every fitness datum so the
ONE reported number reads as the hero measurement it is.

Tone words: calibrated · exact · quiet · phosphor. The product promise is
"your fitness stays yours"; the instrument never claims to touch the machine —
it reads the dial.

## Colors

- **base (#0B0F14):** app background — near-black blue-charcoal.
- **surface (#11161D):** cards, panels, inputs.
- **raised (#1A212B):** active nav rows, hover fills.
- **line (#232C38):** 1px hairlines, borders. 1px grid discipline.
- **signal (#F5B64A):** the sole interaction driver — CTA, focus ring,
  active-row edge, kickers. Amber = alive.
- **good (#4ADE80):** fitness values that cleared a threshold, success states.
- **danger (#FF5D5D):** destructive/error states only.
- **ink (#E6EDF3):** primary text.
- **inkMuted (#8A97A8):** secondary text, labels.
- **onSignal (#1A1205):** text ON the amber signal — always dark for contrast.

## Typography

- **display (Inter 700, 3rem, -0.02em):** landing headline — the only place
  scale gets loud.
- **headline (Inter 600, 1.5rem):** page/section titles.
- **body (Inter 400):** interface copy.
- **data (monospace, 600, tnum):** every number, id, and metric — tabular,
  aligned, instrument-grade.
- **data-lg (monospace, 700, 2.25rem):** hero datum — the last-reported fitness.
- **caption (500, 0.8125rem, 0.08em):** kickers, uppercase labels, nav meta.

## Layout & Spacing

- 8px base grid; spacing xs 4 / sm 8 / md 16 / lg 24 / xl 32.
- Max content width 1280px; workspace uses a 220px nav rail + fluid main.
- Data tables use full-width rows with 1px hairlines — no vertical zebra.

## Elevation & Depth

- Flat by default: depth comes from surface-level contrast and 1px hairlines,
  not shadows. One soft shadow tier for floating controls/menus
  (`0 30px 60px -30px rgba(0,0,0,.8)`), tuned at implementation.

## Shapes

- Small radii by design: 4 / 6 / 10 (sm / md / lg). Nothing pill — pill
  telegraphs consumer-chat (t-chat), not instrument.

## Components

- **button-primary:** amber fill, dark `onSignal` text — the one loud action
  per surface.
- **button-secondary:** transparent, hairline border — every non-primary action.
- **input:** surface fill, hairline border; focus = 2px amber border, no glow.
- **card / stat-value / stat-value-good:** surface panels; stat values render
  in mono amber (or green when the value clears a threshold).
- **table-row-hot:** the suggested organism — 3px amber left edge, amber-tinted
  fill, mono data.
- **nav-item / nav-item-active:** quiet muted entries; active = raised fill.

## Do's and Don'ts

- Do use mono tabular numerals for EVERY datum (fitness, ids, generations).
- Do keep exactly one amber action per surface.
- Do use hairlines and 1px rules to structure dense data.
- Don't use gradients, glassmorphism, or glow — an instrument doesn't glow.
- Don't make pills/rounded-24 for interactive controls.
- Don't put marketing copy on workspace surfaces; the workspace is a Monitor
  surface, the landing is the only Decide/Learn surface.
- Don't claim paid-tier features before the first payer (red line).