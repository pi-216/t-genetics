# PRD-0004 — Graphical chromosome designer & generation browser
# Drift flags vs PRD-0004:
# - Single-page designer form (open question A1 resolved to single surface).
# - Fitness trend = self-hosted pure-CSS/SVG bars, no charting gem (A2 resolved;
#   no external charting CDN — dependency + network red line).
# - The designer replaces the current chromosome CRUD views (A3 resolved to
#   replace — one surface, no split).
# - All scenarios @wip until implemented. No paid-tier visualization depth.

@PRD-0004
@wip
Feature: Chromosome Designer
  As an organization member
  I want to design chromosomes visually and browse generations
  So that I can shape my genome and watch my evolution progress

  Background:
    Given I am signed in as an owner of "Loop Labs"

  @DEV-0001
  Scenario: A user designs a chromosome with mixed allele types and sees a live preview
    When I create a chromosome with a float, an integer, and a boolean allele
    Then I see a live preview of all three alleles
    And the chromosome is saved under my organization

  @DEV-0002
  Scenario: Allele bounds are validated inline
    Given I am adding a float allele to a chromosome
    When I set a minimum greater than the maximum
    Then I see an inline validation error
    And the allele is not saved

  @DEV-0003
  Scenario: An option allele requires a non-empty choice list
    Given I am adding an option allele to a chromosome
    When I leave the choice list empty
    Then I see an inline validation error

  @DEV-0004
  Scenario: Another organization cannot access my chromosome
    Given I am signed in as an owner of organization "Beta"
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