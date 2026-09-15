# Template parity (issue #172) — the rails-venture-template force-live Turbo
# wiring (template.rb, commit b9cfeb5) was never backfilled into this repo:
# the gems sat in the Gemfile with no importmap pins for Stimulus, no
# app/javascript/controllers/, and no body data-turbo-morph. These scenarios
# assert the wiring is LIVE at the transport layer. Both run @javascript (a
# feature tag so both inherit the headless-Chrome driver,
# gherkin_specs/support/capybara_javascript.rb): Stimulus boot and element
# connection exist only in a real browser that executes the served JS —
# rack_test renders no layout and runs no JS, so a request-layer green here
# would be the exact dead-Turbo failure the elo-picker incident shipped.

@PLATFORM-0172 @javascript
Feature: Turbo Stimulus Wiring
  As the platform
  I want Turbo page morphing and Stimulus controllers to be live in every page
  So that the shared layout ships working interactive behavior, not dead JS

  Scenario: The shared layout enables Turbo page morphing
    When I view the landing page
    Then the page body enables page morphing

  Scenario: Stimulus controllers receive their connected behavior
    When I view the landing page
    Then a Stimulus controller element receives its connected behavior
