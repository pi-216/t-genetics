# PRD-0005 — Token API for machines
# Drift flags vs PRD-0005:
# - Builds on PRD-0002 orgs (ApiToken belongs to an org; owner-only create).
#   Tickets stay un-approved until auth's org model lands (build order).
# - Flat tokens: no scopes/rate-limiting/OAuth in v1 (founder ruling).
# - Endpoints under /api/v1, Bearer auth; exact payloads reconciled with the
#   existing rswag artifact during implementation.
# - DEV-0001 implemented (issue #36); DEV-0002 implemented (issue #37).
#   DEV-0003..DEV-0010 remain @wip.

@PRD-0005
Feature: Token API
  As an organization owner
  I want machines to authenticate with API tokens and drive the loop over HTTP
  So that automated systems can CRUD chromosomes and run experiments

  Background:
    Given organization "Loop Labs" owns chromosome "Alpha-chrom"

  @DEV-0001
  Scenario: The owner creates an API token and sees it once
    When I create an API token named "ci-runner" for "Loop Labs"
    Then I see the plaintext token exactly once

  @DEV-0002
  Scenario: A member cannot create or revoke tokens
    Given I am signed in as a member of "Loop Labs"
    When I try to create an API token
    Then I receive a forbidden response and no token is created

  @DEV-0003 @wip
  Scenario: A valid token authenticates chromosome reads
    Given "Loop Labs" has a valid API token
    When I GET /api/v1/chromosomes with that token
    Then I receive a 200 response listing "Alpha-chrom"

  @DEV-0004 @wip
  Scenario: An invalid, missing, or revoked token is rejected
    Given "Loop Labs" has a revoked API token
    When I GET /api/v1/chromosomes with an invalid token
    Then I receive a 401 response

  @DEV-0005 @wip
  Scenario: Tokens are org-scoped
    Given organization "Beta" owns no chromosomes
    When I GET /api/v1/chromosomes of "Loop Labs" using "Beta"'s token
    Then I do not see "Alpha-chrom"

  @DEV-0006 @wip
  Scenario: Machines can create chromosomes with a token
    When I create a chromosome named "Gamma-chrom" via the API
    Then "Gamma-chrom" appears in the API chromosome list

  @DEV-0007 @wip
  Scenario: Machines can create an experiment with a token
    When I create an experiment on "Alpha-chrom" via the API
    Then the experiment appears in the API experiment list

  @DEV-0008 @wip
  Scenario: Machines can request a suggestion with a token
    When I request a suggestion for the experiment via the API
    Then I receive an organism with values

  @DEV-0009 @wip
  Scenario: Machines can report a fitness outcome with a token
    Given a suggestion has been requested for the experiment
    When I report fitness 0.81 for that suggestion via the API
    Then the outcome is recorded on the performance log

  @DEV-0010 @wip
  Scenario: Malformed payloads return validation errors
    When I send a malformed chromosome payload via the API
    Then I receive a 422 response with error keys