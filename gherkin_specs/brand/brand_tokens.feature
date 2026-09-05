# PRD-0006 — Lab Instrument brand tokens apply-pass
# Drift flags vs PRD-0006:
# - Mechanical restyle only: tokens come from docs/design-sprint/ph1/DESIGN.md
#   (locked 2026-09-04). No redesign, no copy changes, no new components.
# - Computed-style assertions (@javascript) need the headless Chrome driver
#   (gherkin_specs/support/capybara_javascript.rb) — see the landing
#   feature's DEV-0005 note for the same reason.
# - Unimplemented scenarios stay @wip (cucumber --strict skips them).
# - DEV-0002 "mono caption face": DESIGN.md button-primary.typography points
#   at typography.caption (family Inter per its fontFamily token), but the
#   founder-ruled Direction A moodboard renders CTAs in the mono face
#   (docs/design-sprint/ph1/moodboard.html .pv-btn) and this scenario is
#   authoritative: the CTA gets caption METRICS (0.8125rem / 500 /
#   +0.08em tracking) applied in the shared layout's mono default face.
# - DEV-0003 kicker face: DESIGN.md components.kicker.typography references
#   typography.caption (Inter family), but the founded-ruled Direction A
#   moodboard + skeleton render kickers in the mono face with uppercase
#   (moodboard .A .kicker, skeleton .hero .k). Same resolution as DEV-0002:
#   kickers get signal color + caption METRICS in the mono face.
# - DEV-0003 hero face: DESIGN.md typography.display (Inter 700, 3rem,
#   -0.02em) is normative and asserts the hero h1 NOT in the mono default.

@PRD-0006
Feature: Brand Tokens
  As a visitor
  I want the running app to wear the locked Lab Instrument tokens
  So that the product reads as a dark calibrated instrument, not a scaffold

  Background:
    Given the application theme layer exists

  @DEV-0001
  @javascript
  Scenario: The shared layout renders the brand dark theme
    When I view any page
    Then the page background is the brand base color
    And the page text is the brand ink color
    And no scaffold teal color classes are rendered

  @DEV-0002
  @javascript
  Scenario: The landing primary CTA uses the amber signal button
    When I view the landing page
    Then the primary call to action has the signal background
    And the primary call to action has onSignal text
    And the primary call to action renders in the mono caption face

  @DEV-0003
  @javascript
  Scenario: The landing page declares the brand structure
    When I view the landing page
    Then the section kickers render in the signal color
    And the landing hero renders the display typeface on the base background

  @DEV-0004
  @javascript
  @wip
  Scenario: Numeric data renders in mono tabular numerals
    When I view a page with numeric data
    Then every numeric datum renders in a mono face
    And every numeric datum uses tabular numeral features

  @DEV-0005
  Scenario: The theme layer matches the locked token set
    When I compare the application theme with the locked DESIGN.md tokens
    Then every color token matches
    And every typeface token matches
    And every radius token matches