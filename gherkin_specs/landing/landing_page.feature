# PRD-0001 — Public landing page
# Drift flags vs PRD-0001:
# - Functional/brand-neutral first pass: the design sprint's brand tokens land
#   later as a mechanical restyle — acceptance here is content + structure,
#   not final look.
# - No paid-tier promise on the page (red line): pricing teaser stays "Free
#   basic loop; paid time-to-result optimization later".
# - Domain TBD (gaas.pi216.ai vs bought) — tests assert the sign-up path, not
#   an absolute URL.
# - DEV-0005 (responsive on mobile) carries @javascript: "no horizontal
#   scrolling" is a live-layout measurement rack_test cannot perform, so it
#   runs under headless Chrome (Capybara.javascript_driver, see
#   gherkin_specs/support/capybara_javascript.rb). The viewport meta it
#   asserts lives in the shared application layout, so the guard covers every
#   page, not just the landing page.
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

  @DEV-0002
  Scenario: The call to action leads to sign-up
    When I click the "Start free" call to action
    Then I land on the sign-up page

  @DEV-0003
  Scenario: The page explains that the customer keeps their fitness function
    When I read the trust section
    Then I see a statement that my fitness function stays mine

  @DEV-0004
  Scenario: The page shows a pricing posture teaser without promising paid features
    When I read the pricing section
    Then I see a Free tier for the basic loop
    And I see no paid feature specifics implemented

  @DEV-0005
  @javascript
  Scenario: The page is responsive on mobile
    When I view the page at a 480 pixel viewport
    Then the page declares a responsive viewport
    And there is no horizontal scrolling

  @DEV-0006
  Scenario: The footer has privacy and terms placeholders
    When I inspect the page footer
    Then I see a privacy link
    And I see a terms link

  @DEV-0007
  Scenario: The page makes no external network calls
    When I inspect the page resources
    Then I see no external scripts, stylesheets, or images

  # Issue #132 (founder direction 2026-09-06): the landing page sweep. New
  # sections explain what a GA is, show concrete use cases, and walk through
  # creating a genome with REAL screenshots of the live designer and
  # experiment workspace (captured from the running app at desktop + mobile
  # widths, served as local assets — never mockups, never external hosts).

  @DEV-0142
  Scenario: The page explains what a genetic algorithm is in plain language
    When I read the GA primer section
    Then I see a plain-language explanation of a genetic algorithm
    And I see that the loop searches a design space the customer owns

  @DEV-0143
  Scenario: The page shows concrete use cases
    When I read the use case cards
    Then I see at least three use cases
    And I see the payment form tip suggestion use case

  @DEV-0144
  Scenario: The page walks through creating a genome with real screenshots
    When I read the genome walkthrough section
    Then I see an explanation of typed alleles
    And I see a real screenshot of the chromosome designer served from the app
    And I see a real screenshot of the experiment workspace served from the app