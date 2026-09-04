# PRD-0001 — Public landing page
# Drift flags vs PRD-0001:
# - Functional/brand-neutral first pass: the design sprint's brand tokens land
#   later as a mechanical restyle — acceptance here is content + structure,
#   not final look.
# - No paid-tier promise on the page (red line): pricing teaser stays "Free
#   basic loop; paid time-to-result optimization later".
# - Domain TBD (gaas.pi216.ai vs bought) — tests assert the sign-up path, not
#   an absolute URL.
# - Unimplemented scenarios stay @wip (cucumber --strict skips them).

@PRD-0001
Feature: Landing Page
  As a visitor
  I want a public landing page that explains the loop and leads me to sign up
  So that I can understand the product and start a trial

  Background:
    Given I am on the landing page

  @DEV-0001
  Scenario: The landing page renders with the core message
    When I read the page content
    Then I see the product name
    And I see an explanation of the evolution loop
    And I see a "Start free" call to action

  @wip
  @DEV-0002
  Scenario: The call to action leads to sign-up
    When I click the "Start free" call to action
    Then I land on the sign-up page

  @wip
  @DEV-0003
  Scenario: The page explains that the customer keeps their fitness function
    When I read the trust section
    Then I see a statement that my fitness function stays mine

  @wip
  @DEV-0004
  Scenario: The page shows a pricing posture teaser without promising paid features
    When I read the pricing section
    Then I see a Free tier for the basic loop
    And I see no paid feature specifics implemented

  @wip
  @DEV-0005
  Scenario: The page is responsive on mobile
    When I view the page at a 480 pixel viewport
    Then the page declares a responsive viewport
    And there is no horizontal scrolling

  @wip
  @DEV-0006
  Scenario: The footer has privacy and terms placeholders
    When I inspect the page footer
    Then I see a privacy link
    And I see a terms link

  @wip
  @DEV-0007
  Scenario: The page makes no external network calls
    When I inspect the page resources
    Then I see no external scripts or stylesheets