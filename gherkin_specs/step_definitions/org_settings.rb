# frozen_string_literal: true

# Step definitions for DEV-0008 — a member cannot manage members or
# tokens (PRD-0002 / issue #18). The org settings page renders the
# member-management and token-management sections owner-only; a member
# visiting the page sees neither section.
Given(/^I visit the organization settings$/) do
  visit settings_path
end

Then(/^I do not see member management$/) do
  expect(page).not_to have_content('Member management')
end

Then(/^I do not see token management$/) do
  expect(page).not_to have_content('Token management')
end
