# frozen_string_literal: true

# Step definitions for PRD-0001 — public landing page (DEV-0001: the page
# renders with the core message; DEV-0002: the call to action leads to
# sign-up). Public route, no auth, no DB — plain Capybara/rack_test
# assertions against the root route.

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

# DEV-0002 — the "Start free" CTA on the landing page links into the
# PRD-0002 sign-up flow. The sign-up page is identified by its heading
# (same marker the registration steps assert).
When(/^I click the "([^"]+)" call to action$/) do |label|
  click_link label
end

Then(/^I land on the sign-up page$/) do
  expect(page).to have_current_path(register_path)
  expect(page).to have_content('Create your account')
end

# DEV-0003 — the landing page carries a trust block that states the core
# product contract: the customer keeps their fitness function. We never
# run or evaluate it for them (HANDOFF red line); the page just says so.
When(/^I read the trust section$/) do
  expect(page).to have_css('#trust')
end

Then(/^I see a statement that my fitness function stays mine$/) do
  expect(page).to have_content('Your fitness function stays yours')
end
