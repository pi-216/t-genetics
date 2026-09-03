# PRD-0002 — Organization sign-up & authentication
# Greenlit 2026-09-03 by the founder — auth is the first buildable slice.
# Drift flags vs PRD-0002:
# - Invite flow: v1 = owner-generated invite CODE shared manually (no outgoing
#   email — keeps the no-external-sends red line). Email-link invites deferred
#   until mail infra + founder sign-off.
# - One org per user for v1 (single membership; A2 resolved).
# - Org display name: free text at sign-up (A4 resolved).
# - All scenarios @wip until implemented (cucumber --strict excludes @wip).
#   Tag order (@DEV-0001..) = build order; foundational auth first.
# - Auth mechanism: email+password (Devise, t-chat house pattern). DESIGN is
#   NOT part of this slice — functional styling only (brand lands later via
#   the design sprint).

@PRD-0002
Feature: Organization Auth
  As a visitor
  I want to create an organization account, sign in, and manage members
  So that my team can use the genetic-algorithm loop with isolated org data

  Background:
    Given I am on the sign-up page

  @DEV-0001
  Scenario: Signing up creates an organization with me as owner
    When I sign up with the following details:
      | email           | password    | organization |
      | ada@example.com | S3cretPass! | Loop Labs    |
    Then I am signed in with an organization named "Loop Labs"
    And I am the owner of "Loop Labs"

  @DEV-0002
  Scenario: Duplicate email is rejected on sign-up
    Given a user exists with email "ada@example.com"
    When I sign up with the following details:
      | email           | password    | organization |
      | ada@example.com | S3cretPass! | Loop Labs    |
    Then I see a validation error about the email being taken
    And no new account or organization is created

  @DEV-0003
  Scenario: Signing in with valid credentials succeeds
    Given a user exists with email "ada@example.com" and password "S3cretPass!"
    When I sign in with email "ada@example.com" and password "S3cretPass!"
    Then I am signed in

  @DEV-0004
  Scenario: Signing in with invalid credentials fails safely
    Given a user exists with email "ada@example.com" and password "S3cretPass!"
    When I sign in with email "ada@example.com" and password "wrong-password"
    Then I am not signed in
    And I see a generic invalid-credentials error

  @DEV-0005
  Scenario: Signing out terminates my session
    Given I am signed in
    When I sign out
    Then I am not signed in

  @DEV-0006
  @wip
  Scenario: The owner can generate an invite code
    Given I am signed in as the owner of "Loop Labs"
    When I generate an invite code for my organization
    Then I see an invite code that lets others join "Loop Labs"

  @DEV-0007
  @wip
  Scenario: Joining with an invite code adds me as a member
    Given the owner of "Loop Labs" has generated invite code "INVITE-ABC"
    When I join "Loop Labs" with the following details:
      | invite_code | email           | password    |
      | INVITE-ABC  | bob@example.com | S3cretPass! |
    Then I am signed in as a member of "Loop Labs"
    And "bob@example.com" is a member, not an owner, of "Loop Labs"

  @DEV-0008
  @wip
  Scenario: A member cannot manage members or tokens
    Given I am signed in as a member of "Loop Labs"
    When I visit the organization settings
    Then I do not see member management
    And I do not see token management

  @DEV-0009
  @wip
  Scenario: Org A's user cannot access Org B's chromosomes
    Given organization "Alpha" owns a chromosome named "Alpha-chrom"
    And organization "Beta" has a user with email "grace@example.com"
    When the user "grace@example.com" visits the chromosome "Alpha-chrom"
    Then I receive a not-found or forbidden response
    And the chromosome is not disclosed

  @DEV-0010
  @wip
  Scenario: The last owner cannot be removed or demoted
    Given "Loop Labs" has one owner "ada@example.com" and a member "bob@example.com"
    When "ada@example.com" attempts to remove her own owner role
    Then the removal is rejected
    And "ada@example.com" remains the owner of "Loop Labs"