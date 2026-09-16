# PRD-0007 — API token management (web UI)
# Drift flags vs PRD-0007:
# - Builds on PRD-0005 (ApiToken model + minimal create-on-settings surface
#   shipped via A1). This PRD replaces the bare settings-page create form and
#   <li> list with a dedicated management page: list all tokens, one-time
#   plaintext reveal + copy, revoke, empty state, nav entry, last-used
#   metadata.
# - Flat tokens preserved: no scopes/expiry/rotation in v1 (PRD-0005 ruling).
#   Revoke + recreate is the rotation path; token name is fixed at creation.
# - Revocation semantics unchanged: only active (non-revoked) tokens
#   authenticate /api/v1 (TokenAuthentication) — this PRD surfaces the revoke
#   action in the web UI, it does not change the middleware.
# - All scenarios @wip until implemented (cucumber --strict excludes @wip);
#   @DEV tag order = build order.

@PRD-0007
Feature: API token management
  As an organization owner
  I want a web interface to manage my org's API tokens
  So that I can issue, identify, and revoke the credentials machines use

  Background:
    Given organization "Loop Labs" owns a valid API token named "ci-runner"

  @javascript
  @DEV-0001
  Scenario: The owner can open a dedicated token management page
    Given I am signed in as the owner of "Loop Labs"
    When I open the API token management page
    Then I see a list of API tokens for "Loop Labs"
    And I see "ci-runner" marked active

  @javascript
  @DEV-0002
  Scenario: The token management page is reachable from the navigation
    Given I am signed in as the owner of "Loop Labs"
    When I click the token management link in the navigation
    Then I land on the API token management page

  @javascript
  @DEV-0003
  @wip
  Scenario: The owner creates a token and copies the one-time plaintext
    Given I am signed in as the owner of "Loop Labs"
    When I create an API token named "staging-runner"
    Then I see the plaintext token exactly once
    And I can copy it from the page
    And "staging-runner" appears in the token list

  @javascript
  @DEV-0004
  @wip
  Scenario: The owner revokes an active token
    Given I am signed in as the owner of "Loop Labs"
    When I revoke the token "ci-runner"
    Then "ci-runner" is shown as revoked in the list
    And the plaintext token is never shown again

  @DEV-0005
  @wip
  Scenario: A revoked token stops authenticating the API immediately
    Given "ci-runner" has been revoked by its owner
    When I GET /api/v1/chromosomes with the revoked token
    Then I receive a 401 response

  @DEV-0006
  @wip
  Scenario: A member cannot manage API tokens
    Given I am signed in as a member of "Loop Labs"
    When I request the API token management page
    Then I receive a forbidden response
    And no token is created or revoked

  @javascript
  @DEV-0007
  @wip
  Scenario: The token list shows when each token was last used
    Given "ci-runner" was last used on 2026-09-15
    And "Loop Labs" owns an unused API token named "idle-runner"
    When I open the API token management page
    Then I see the last-used date for "ci-runner"
    And I see "idle-runner" marked as never used

  @javascript
  @DEV-0008
  @wip
  Scenario: An organization with no tokens sees an empty state
    Given organization "Empty Labs" has no API tokens
    And I am signed in as the owner of "Empty Labs"
    When I open the API token management page
    Then I see guidance to create the first API token
