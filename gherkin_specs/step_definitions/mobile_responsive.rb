# frozen_string_literal: true

# Step definitions for PRD-0001 DEV-0005 — the page is responsive on mobile.
#
# These steps need a REAL layout engine (@javascript / headless Chrome):
# rack_test renders no layout, so window resizing is unsupported and
# documentElement.scrollWidth cannot be measured. The viewport-meta assertion
# targets the shared application layout, so it guards every page.
#
# Sabotage discipline (proven in the DEV-0005 PR):
#   - removing the viewport meta from the layout kills the meta step;
#   - adding any fixed-width/overflowing element (e.g. min-width: 600px on
#     the body) kills the no-horizontal-scrolling step.

When(/^I view the page at a (\d+) pixel viewport$/) do |width|
  # Requires a JS driver. Under rack_test there is no #manage (NoMethodError),
  # so the step fail-closes if the scenario ever loses its @javascript tag.
  page.driver.browser.manage.window.resize_to(width.to_i, 800)
end

Then(/^the page declares a responsive viewport$/) do
  # Prefix match: "width=device-width,…" must be the LEADING declaration, so a
  # malformed value like "width=device-widthX" does not pass.
  expect(page).to have_css('meta[name="viewport"][content^="width=device-width"]', visible: false)
end

Then(/^there is no horizontal scrolling$/) do
  # Headless assumption: in headless Chrome window.innerWidth equals the CSS
  # viewport width, so the documentElement scrollWidth comparison is exact.
  scroll_width = page.evaluate_script('document.documentElement.scrollWidth')
  viewport_width = page.evaluate_script('window.innerWidth')
  expect(scroll_width).to be <= viewport_width
end
