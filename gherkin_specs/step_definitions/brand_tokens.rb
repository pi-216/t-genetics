# frozen_string_literal: true

# Step definitions for PRD-0006 — Lab Instrument brand tokens apply-pass.
#
# These steps are shared by the @PRD-0006 scenarios. DEV-0001 (the shared
# layout renders the brand dark theme) is @javascript: it measures REAL
# computed styles in headless Chrome, so the assertions cannot be fooled by
# a class that is declared but never applied. The theme-layer Background
# step is driver-independent.
#
# Sabotage discipline (proven in the DEV-0001 PR):
#   - deleting app/assets/stylesheets/theme.css (or dropping --color-base
#     from it) kills the Background step;
#   - restoring the scaffold teal classes on the shared layout body/footer
#     kills all three Then steps: computed background != base, computed
#     text != ink, and the teal class scan finds classes.
# The computed-style path fail-closes if a scenario ever loses its
# @javascript tag (page.evaluate_script raises under rack_test).

Given(/^the application theme layer exists$/) do
  # The theme layer is the Tailwind v4 @theme block mechanically exported
  # from the locked DESIGN.md (docs/design-sprint/ph1/DESIGN.md) by the
  # designmd CLI — generated, never hand-edited (PRD-0006 edge case).
  theme_css = Rails.root.join('app/assets/stylesheets/theme.css')
  expect(theme_css).to exist
  expect(File.read(theme_css)).to include('--color-base')
end

When(/^I view any page$/) do
  # DEV-0001: the shared application layout is the surface under test, so
  # the public landing page (root) is the deterministic "any page".
  visit root_path
end

Then(/^the page background is the brand base color$/) do
  # DESIGN.md base #0B0F14 -> computed rgb(11, 15, 20). Requires a real
  # layout engine — rack_test renders no layout and would raise here.
  background = page.evaluate_script('getComputedStyle(document.body).backgroundColor')
  expect(background).to eq('rgb(11, 15, 20)')
end

Then(/^the page text is the brand ink color$/) do
  # DESIGN.md ink #E6EDF3 -> computed rgb(230, 237, 243). Real layout
  # engine required; rack_test raises, fail-closing a lost @javascript tag.
  color = page.evaluate_script('getComputedStyle(document.body).color')
  expect(color).to eq('rgb(230, 237, 243)')
end

Then(/^no scaffold teal color classes are rendered$/) do
  # Scans EVERY rendered element's class attribute (visible and hidden) for
  # the Rails scaffold's teal palette — one teal class anywhere is a fail.
  teal_classes = page.all('*', visible: false).filter_map { |el| el[:class].to_s }
                     .select { |cls| cls.include?('teal') }
  expect(teal_classes).to be_empty
end
