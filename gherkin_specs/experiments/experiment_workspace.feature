# PRD-0003 — Experiment workspace (the loop, in the UI)
# Drift flags vs PRD-0003:
# - Evolution stays automatic and badge-indicated only (open question A1
#   resolved to badge — no manual "Evolve now" button in v1).
# - Re-reporting a fitness value is allowed with an audit trail on the log
#   (open question A2 resolved to yes).
# - Population size + ripe thresholds are set at creation (open question A3
#   resolved to yes — they already exist on the model).
# - DEV-0001 (issue #68) and DEV-0003 (issue #70) implemented; DEV-0002,
#   DEV-0004..DEV-0008 still @wip (each gets its own ticket). No paid-tier
#   surface (exploitation/greed, generation-progress insights) — those are red
#   lines until a payer.

@PRD-0003
Feature: Experiment Workspace
  As an organization member
  I want to create an experiment, get an organism to test, and report one fitness number back
  So that I can run the genetic-algorithm loop against my own fitness function

  Background:
    Given organization "Loop Labs" owns chromosome "Alpha-chrom"
    And I am signed in as an owner of "Loop Labs"

  @DEV-0001
  Scenario: A member creates an experiment with a chromosome and population size
    When I create the "Donation amounts" experiment on "Alpha-chrom" with population 20
    Then I see the experiment under my organization
    And evolution is not yet ripe

  @DEV-0002
  @wip
  Scenario: Another organization cannot see my experiment
    Given I am signed in as an owner of organization "Beta"
    When I visit the experiment "Donation amounts"
    Then I receive a not-found or forbidden response

  @DEV-0003
  Scenario: A member can request a suggestion
    When I request a suggestion for the experiment
    Then I receive an organism with values from the current generation
    And a performance log entry records the suggestion

  @DEV-0004
  @wip
  Scenario: Reporting an outcome records exactly one fitness number
    Given a suggestion has been requested for the experiment
    When I report fitness 0.81 for that suggestion
    Then the fitness 0.81 is recorded against that suggestion

  @DEV-0005
  @wip
  Scenario: A ripe experiment evolves to a new generation on the next loop action
    Given the experiment has enough reported outcomes to be ripe
    When I request the next suggestion
    Then a new generation is created
    And it replaces the current generation

  @DEV-0006
  @wip
  Scenario: Evolution does not double-fire
    Given the experiment is ripe
    When the next loop action runs twice
    Then exactly one new generation is created

  @DEV-0007
  @wip
  Scenario: I can browse generation history
    Given the experiment has evolved more than once
    When I open the generation history
    Then I see each generation with its organisms and recorded fitness

  @DEV-0008
  @wip
  Scenario: An empty generation shows an explicit empty state
    Given the experiment has no organisms to suggest
    When I request a suggestion
    Then I see an explicit message that no suggestion is available