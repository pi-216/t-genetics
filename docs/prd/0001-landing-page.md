# PRD-0001 — Public landing page

## Summary
A public landing page at the product root (`/`) that positions the GAaaS loop
("suggest an organism to test → test it against your fitness → report ONE
number → we breed offspring → repeat"), shows the pricing posture (free basic
loop; paid tier = time-to-result optimization later), and funnels visitors to
sign-up.

## Problem / motivation
There is no public face. The loop is invisible until a human can understand in
one screen what the product does, that their fitness function stays theirs, and
where to start. The landing page is the falsification instrument's front door —
nothing else converts a curious visitor into a trial user.

## Goals / Non-goals
- Goals: one clear page; the loop explained in ≤5 bullet points; a "start free"
  call-to-action to org sign-up (PRD-0002); footer with privacy/terms placeholders;
  responsive (mobile-first per house style).
- Non-goals (Out): pricing calculator, paid-tier marketing deep-dive, blog,
  case studies, marketing analytics beyond a single page-view counter, SEO
  content, chat widget.

## Scope — In / Out
**In:** hero (product name + one-line value prop), "how it works" (the 5-step
loop), a "you keep your fitness function" trust block, pricing posture teaser
(Free = basic loop; Paid = later), CTA → sign-up, footer (privacy/terms/contact
placeholders), mobile-first responsive layout.
**Out:** everything under Non-goals. No external sends/spend/accounts — the page
must not fire emails, ads, or analytics beacons that cost money.

## Acceptance criteria
- `GET /` renders 200 with product name, loop explanation, and a sign-up CTA.
- CTA links to the PRD-0002 sign-up route.
- Page is mobile-first responsive (no horizontal scroll at 480px).
- No external network calls / beacons / paid integrations fire on page load.
- Footer contains privacy/terms placeholder links.
- Owned by a `Landing` pack (or root `app/` with `LandingController`); no auth
  required; spec'd via request spec + BDD.

## Edge cases & red lines
- Content must not claim paid features exist before the first payer (red line).
- No real-person likeness/voice anywhere on the page.
- AI-disclosure: if the demo loop is shown, label it "simulated fitness" clearly.
- No analytics that send data off-domain.

## Metrics / definition of done
- Request spec green (200, CTA present, no beacons); BDD green; `bin/verify` green.
- LCP < 2.5s on a 4G throttle (server-rendered page, no heavy assets).

## Open questions (product owner)
- **A1 Copy:** who does the value-prop copy? (Recommend: draft in PRD, refine
  after the design sprint's brand concept.)
- **A2 Domain:** does the product run at `gaas.pi216.ai` or a bought domain?
  (Affects canonical URLs / meta; recommend `gaas.pi216.ai` for the trial.)
- **A3 Demo:** embed the standalone `demo/index.html` GA simulation as a
  scroll-triggered section, or keep the page purely static? (Recommend: embed —
  it's the falsification hook, labeled simulated.)

## Related
- PRD-0002 (org sign-up) — the CTA target.
- Design sprint output (brand tokens) — applied to this page first.