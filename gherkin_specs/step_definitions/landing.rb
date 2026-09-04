# frozen_string_literal: true

# Step definitions for PRD-0001 — public landing page (DEV-0001: the page
# renders with the core message). Public route, no auth, no DB — plain
# Capybara/rack_test assertions against the root route.

Given(/^I am on the landing page$/) do
  visit root_path
  expect(page).to have_current_path(root_path)
end

When(/^I read the page content$/) do
  expect(page.status_code).to eq(200)
end

Then(/^I see the product name$/) do
  expect(page).to have_content('TGenetics')
end

Then(/^I see an explanation of the evolution loop$/) do
  expect(page).to have_content('report one number')
  expect(page).to have_content('offspring')
end

Then(/^I see a "([^"]+)" call to action$/) do |label|
  expect(page).to have_link(label, href: register_path)
end
