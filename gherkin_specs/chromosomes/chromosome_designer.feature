# PRD-0004 — Chromosome & allele management (standard CRUD)
# Drift flags vs PRD-0004:
# - A3 (2026-09-15, issue #184, PO ruling): the single-surface "designer"
#   (inline allele cards + Add-allele round trip + live preview) is REPLACED
#   by standard CRUD operations — create the chromosome by name only, land
#   on its show page, then add/edit/destroy alleles through their own nested
#   forms (each mutation redirecting back to the show page). The scenarios
#   below encode that flow.
# - Fitness trend = self-hosted pure-CSS/SVG bars, no charting gem (A2
#   resolved; no external charting CDN — dependency + network red line).
# - DEV-0004 (issue #80) implemented: cross-org chromosome access answers
#   404; DEV-0006 (issue #82, fitness trend line) and DEV-0007 (issue #83,
#   explicit empty state) implemented.
# - DEV-0004 drift: the published scenario references "Alpha-chrom" without
#   creating it — the implicit prerequisite "organization Alpha owns a
#   chromosome named Alpha-chrom" is injected (reuses the PRD-0002 DEV-0009
#   step in org_scoping.rb) so the 404 proves cross-org blocking, not mere
#   absence of the chromosome.
# - No paid-tier visualization depth.

@PRD-0004
Feature: Chromosome Designer
  As an organization member
  I want to create chromosomes and manage their typed alleles with standard CRUD
  So that I can shape my genome and watch my evolution progress

  Background:
    Given I am signed in as an owner of "Loop Labs"

  @DEV-0001
  # Issue #184 — the create flow is name-only; alleles are added afterwards
  # through the nested allele form. @javascript: the new-allele form posts
  # through a real browser (the transport layer that used to swallow the
  # designer's re-renders — finding #147 class).
  @javascript
  Scenario: A user creates a chromosome by name
    When I create a chromosome with the name "Mixed genome"
    Then I see the empty allele state on the chromosome
    And the chromosome is saved under my organization

  @DEV-0001
  # Issue #184 — PO ruling: "Once done you end up on the show page of the
  # chromosome, now showing the one allele."
  @javascript
  Scenario: Adding an allele returns to the chromosome show page
    Given a chromosome named "Mixed genome"
    When I add a float allele "weight" bounded by 0 and 10
    Then I am back on the chromosome show page and see the allele "weight"

  @DEV-0151
  # Issue #151 (T3 gap) — saved-state-integrity guard, on the CRUD flow now:
  # the alleles added one at a time persist EXACTLY — count and names — never
  # fewer or duplicated. Real browser because T3 lived in the transport layer.
  @javascript
  Scenario: A chromosome is saved with exactly the alleles added
    Given a chromosome named "Mixed genome"
    When I add a float allele "weight" 0..10, integer "limbs" 2..4, boolean "wings"
    Then the chromosome is saved with exactly those 3 alleles

  @DEV-0002
  # Finding #147 (T1) — inline validation on the allele form: the 422
  # re-render must display in a real browser (the allele form opts out of
  # Turbo, same transport class as the old designer form).
  @javascript
  Scenario: Allele bounds are validated inline
    Given I am adding a float allele to a chromosome
    When I set a minimum greater than the maximum
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0003
  # Inline validation re-renders on the allele form — the same transport
  # class as findings T1/T2: only the browser proves the 422 displays.
  @javascript
  Scenario: An option allele requires a non-empty choice list
    Given I am adding an option allele to a chromosome
    When I leave the choice list empty
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0210
  # Issue #210 — the web form posts `allele[choices]` as ONE comma-separated
  # string (a single text input), unlike the machine contract's array; the
  # happy path must round-trip through a real browser, not just the JSON API.
  @javascript
  Scenario: An option allele is created from a comma-separated choice list
    Given a chromosome named "Mixed genome"
    When I add an option allele "color" with the choices "red, blue"
    Then I am back on the chromosome show page and see the allele "color"
    And the allele "color" shows the choices "red, blue"

  @DEV-0148
  # Finding #148 (T2) — type-aware allele fields: the allele form reveals
  # only the fields the selected type needs (Stimulus toggle in a real
  # browser; server-side validation stays the source of truth).
  @javascript
  Scenario: The allele form renders only the fields each allele type needs
    Given I am adding an allele to a chromosome
    When I walk the allele form through every allele type
    Then each allele form shows only its type's fields

  @DEV-0149
  # Finding #149 — duplicate allele names are rejected by the model-level
  # scoped uniqueness; adding a second allele with an existing name must
  # fail inline and persist nothing.
  @javascript
  Scenario: Duplicate allele names are rejected inline
    Given a chromosome with an allele named "weight"
    When I add another allele named "weight"
    Then I see an inline validation error
    And the duplicate allele is not saved

  @DEV-0004
  Scenario: Another organization cannot access my chromosome
    Given organization "Alpha" owns a chromosome named "Alpha-chrom"
    And I am signed in as an owner of organization "Beta"
    When I visit the chromosome "Alpha-chrom"
    Then I receive a not-found or forbidden response

  @DEV-0005
  Scenario: I can open an organism and see its typed values
    Given the generation browser shows an organism
    When I open the organism
    Then I see each value rendered by its allele type

  @DEV-0006
  Scenario: The fitness trend shows a line from recorded fitness
    Given the experiment has generations with recorded fitness
    When I view the fitness trend
    Then I see a per-generation trend line
    And no external charting is loaded

  @DEV-0007
  Scenario: The fitness trend shows an explicit empty state when no fitness is recorded
    Given the experiment has no recorded fitness
    When I view the fitness trend
    Then I see an explicit empty state

  @DEV-0203
  # Issue #203 — the page-header back link must left-align with the kicker and
  # title directly below it; the button kit's px-4 base padding indented the
  # link 16px. Only real layout can prove the alignment, so this measures the
  # actual left edges in headless Chrome (same class as the brand-token
  # computed-style scenarios — rack_test renders no layout).
  @javascript
  Scenario: The page-header back link left-aligns with the heading
    Given a chromosome named "Mixed genome"
    When I open the new allele form for the chromosome
    Then the back link and the heading share the same left edge

  @DEV-0209
  # Issue #209 — a successful mutation must confirm itself on the page it
  # redirects to. The shared layout renders the flash now; before, the notice
  # had no surface at all, so a committed allele looked like a silent failure.
  # Real browser: the step drives the form and the redirect it triggers.
  @javascript
  Scenario: Adding an allele confirms itself on the chromosome show page
    Given a chromosome named "Mixed genome"
    When I add an integer allele "legs" bounded by 2 and 4
    Then I see the success notice "Added allele legs."
