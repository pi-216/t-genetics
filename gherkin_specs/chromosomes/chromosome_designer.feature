# PRD-0004 — Graphical chromosome designer & generation browser
# Drift flags vs PRD-0004:
# - Single-page designer form (open question A1 resolved to single surface).
# - Fitness trend = self-hosted pure-CSS/SVG bars, no charting gem (A2 resolved;
#   no external charting CDN — dependency + network red line).
# - The designer replaces the current chromosome CRUD views (A3 resolved to
#   replace — one surface, no split).
# - DEV-0004 (issue #80) implemented: cross-org chromosome access answers
#   404; DEV-0006 (issue #82, fitness trend line) and DEV-0007 (issue #83,
#   explicit empty state) implemented. The remaining scenarios stay @wip
#   until implemented.
# - DEV-0004 drift: the published scenario references "Alpha-chrom" without
#   creating it — the implicit prerequisite "organization Alpha owns a
#   chromosome named Alpha-chrom" is injected (reuses the PRD-0002 DEV-0009
#   step in org_scoping.rb) so the 404 proves cross-org blocking, not mere
#   absence of the chromosome.
# - No paid-tier visualization depth.
# - Finding #148 (T2): DEV-0148 walks the first allele card through all four
#   types and asserts the field set matches per type — in a real browser
#   (@javascript), because the finding came from a live walk where the
#   request layer (which rendered every field for every type) stayed green.
#   Tag @DEV-0148 (finding lineage, like @DEV-0141..@DEV-0144 for UX fixes).

@PRD-0004
Feature: Chromosome Designer
  As an organization member
  I want to design chromosomes visually and browse generations
  So that I can shape my genome and watch my evolution progress

  Background:
    Given I am signed in as an owner of "Loop Labs"

  @DEV-0001
  # Finding #147 (T1) — see the DEV-0002 note: same Turbo transport. This
  # scenario CLICKS "Add allele" twice in a real browser — precisely the
  # founder's live-walk symptom ("the page never grows past Allele 1") — so
  # it carries @javascript as the transport regression.
  @javascript
  Scenario: A user designs a chromosome with mixed allele types and sees a live preview
    When I create a chromosome with a float, an integer, and a boolean allele
    Then I see a live preview of all three alleles
    And the chromosome is saved under my organization

  @DEV-0002
  # Finding #147 (T1) — the designer form was Turbo-intercepted, so in a real
  # browser the Add-allele round trip (a 200 re-render) was discarded and the
  # page never grew past "Allele 1", while every request-layer gate stayed
  # green (the founder's live walk found it). @javascript proves the transport
  # layer in headless Chrome. Drift flag: the original scenario text is
  # unchanged — only the driver requirement is added.
  @javascript
  Scenario: Allele bounds are validated inline
    Given I am adding a float allele to a chromosome
    When I set a minimum greater than the maximum
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0003
  # Inline validation re-renders on the designer form (Turbo round trip) —
  # the same transport class as findings T1/T2: rack_test saw the error
  # because it never renders the transport; only the browser proves it.
  # @javascript mandated by the issue #150 UI-verb lint for "inline
  # validation" scenarios.
  @javascript
  Scenario: An option allele requires a non-empty choice list
    Given I am adding an option allele to a chromosome
    When I leave the choice list empty
    Then I see an inline validation error

  @DEV-0148
  @javascript
  Scenario: The designer renders only the fields each allele type needs
    Given I am designing a chromosome
    When I walk the first allele card through every allele type
    Then each allele card shows only its type's fields

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