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

When(/^I click the token management link in the navigation$/) do
  click_link 'API tokens'
end

Then(/^I land on the API token management page$/) do
  expect(page).to have_current_path(api_tokens_index_path)
  expect(page).to have_css('h1', text: 'API tokens')
end

Then(/^I see a list of API tokens for "([^"]+)"$/) do |org_name|
  expect(page).to have_css('h1', text: 'API tokens')
  expect(page).to have_content(org_name)
end

Then(/^I see "([^"]+)" marked active$/) do |token_name|
  row = find('tr', text: token_name)
  expect(row).to have_content('Active')
end

# PRD-0007 DEV-0003 / issue #189 — the owner creates a token on the
# management page (the create surface moved off the settings page) and the
# one-time plaintext reveal + copy affordance lands there. The sign-in is the
# scenario's own Given; @plaintext_token is captured for the exactly-once and
# clipboard assertions that follow.
When(/^I create an API token named "([^"]+)"$/) do |token_name|
  visit api_tokens_index_path
  fill_in 'Token name', with: token_name
  click_button 'Create token'
  @plaintext_token = page.find('#token_plaintext_value').text.strip
end

Then(/^I can copy it from the page$/) do
  expect(page).to have_button('Copy')
  button = page.find('#copy_token_plaintext')
  expect(button['data-action']).to include('clipboard-copy#copy')
  expect(page.find('#token_plaintext')['data-clipboard-target']).to eq('#token_plaintext_value')

  button.click

  # Real browser, real click: the Stimulus controller resolves
  # navigator.clipboard.writeText with the reveal element's exact text and
  # only then flips the panel into the copied state — a rejected write never
  # claims success. Chrome holds clipboard-read back from automation scripts,
  # so the OS-clipboard round-trip itself is Chromium's own guarantee for a
  # resolved write; everything testable at the browser boundary is pinned.
  expect(page).to have_css('#token_plaintext[data-copied="true"]', wait: 5)
end

Then(/^"([^"]+)" appears in the token list$/) do |token_name|
  expect(page).to have_css('tr', text: token_name)
end

# PRD-0007 DEV-0004 / issue #190 — the owner revokes an active token from
# the management page. The revoke control is a destructive POST (the revoke
# button carries an onsubmit confirmation); the real-browser driver resolves
# the confirm dialog via Capybara's modal handling, then asserts the row's
# status flips to revoked and the one-time plaintext surface stays absent
# (revocation renders digest-only rows, never plaintext).
When(/^I revoke the token "([^"]+)"$/) do |token_name|
  visit api_tokens_index_path
  row = page.find('tr', text: token_name)
  within(row) do
    accept_confirm { click_button 'Revoke' }
  end
end

Then(/^"([^"]+)" is shown as revoked in the list$/) do |token_name|
  row = page.find('tr', text: token_name)
  expect(row).to have_content('Revoked')
end

Then(/^the plaintext token is never shown again$/) do
  expect(page).not_to have_css('#token_plaintext_value')
end
