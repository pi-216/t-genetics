# frozen_string_literal: true

# Step definitions for PRD-0007 — the dedicated API token management page
# (web UI). The Background mints an active digest-only token for the org
# (same factory truth as PRD-0005's api_tokens.rb steps); the management
# surface steps drive the real browser (@javascript) — the page renders the
# org's token list owner-only.

Given(/^organization "([^"]+)" owns a valid API token named "([^"]+)"$/) do |org_name, token_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  Identity::ApiToken.create!(
    organization: organization,
    name: token_name,
    token_digest: Identity::ApiToken.digest(Identity::ApiToken.generate_plaintext)
  )
end

When(/^I open the API token management page$/) do
  visit api_tokens_index_path
end

Then(/^I see a list of API tokens for "([^"]+)"$/) do |org_name|
  expect(page).to have_css('h1', text: 'API tokens')
  expect(page).to have_content(org_name)
end

Then(/^I see "([^"]+)" marked active$/) do |token_name|
  row = find('tr', text: token_name)
  expect(row).to have_content('Active')
end
