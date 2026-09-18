# frozen_string_literal: true

# Step definitions for PRD-0007 — the dedicated API token management page
# (web UI). The Background mints an active digest-only token for the org
# (same factory truth as PRD-0005's api_tokens.rb steps); the management
# surface steps drive the real browser (@javascript) — the page renders the
# org's token list owner-only.

Given(/^organization "([^"]+)" owns a valid API token named "([^"]+)"$/) do |org_name, token_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  @api_test_org = organization
  Identity::ApiToken.create!(
    organization: organization,
    name: token_name,
    token_digest: Identity::ApiToken.digest(Identity::ApiToken.generate_plaintext)
  )
end

When(/^I open the API token management page$/) do
  visit api_tokens_index_path
end

# PRD-0007 DEV-0007 / issue #193 — the token list shows when each token was
# last used. TokenAuthentication stamps last_used_at on every successful API
# authentication, so the Given only has to write the timestamp the scenario
# wants displayed. The minted row is the org's newest row with that name
# (@javascript truncation wipes rows at each scenario's start, but run-order
# and leftovers from other features must never decide a step's outcome, so
# the pick is explicit: id: :desc). @last_used_label feeds the Then that
# asserts the row's rendered date.
Given(/^"([^"]+)" was last used on ([0-9]{4}-[0-9]{2}-[0-9]{2})$/) do |token_name, date|
  organization = @api_test_org or raise 'no feature-background organization in play'
  token = organization.api_tokens.order(id: :desc).find_by(name: token_name) or raise "no api token named #{token_name} in play"
  token.update!(last_used_at: Time.zone.parse(date))
  @last_used_label = token.last_used_at.to_fs(:short)
end

Given(/^"([^"]+)" owns an unused API token named "([^"]+)"$/) do |org_name, token_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  Identity::ApiToken.create!(
    organization: organization,
    name: token_name,
    token_digest: Identity::ApiToken.digest(Identity::ApiToken.generate_plaintext)
  )
end

# The token list renders one row per token with the name in the first cell.
# Row lookup by exact name cell (never by substring across the whole row) so
# a token whose name is a substring of another's can never be conflated, and
# duplicate rows from earlier scenarios cannot make the find ambiguous.
def token_row(token_name)
  page.find('td:first-child', exact_text: token_name, match: :first).ancestor('tr')
end

Then(/^I see the last-used date for "([^"]+)"$/) do |token_name|
  row = token_row(token_name)
  expect(row).to have_content(@last_used_label)
end

Then(/^I see "([^"]+)" marked as never used$/) do |token_name|
  row = token_row(token_name)
  expect(row).to have_content('Never used')
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

# PRD-0007 DEV-0006 / issue #192 — a member cannot manage API tokens. The
# owner-only before_action on every management action answers 403; the When
# drives the honest page request at the request layer (no @javascript —
# API/auth/data scenarios stay request-layer), the Then asserts the status,
# and the And proves the member's crafted writes (create + revoke) are both
# rejected with 403 AND leave the org's token set untouched — flat roles,
# members never manage tokens (PRD-0005/0007 edge-case ruling). The revoke
# target is the scenario's own Background row (newest id), and the count
# assertion is relative: earlier @javascript scenarios leave rows behind
# (truncation strategy), so absolute counts would be order-dependent.
When(/^I request the API token management page$/) do
  page.driver.get(api_tokens_index_path)
end

Then(/^I receive a forbidden response$/) do
  expect(page.status_code).to eq(403)
end

And(/^no token is created or revoked$/) do
  organization = @api_test_org or raise 'no feature-background organization in play'
  token = organization.api_tokens.order(id: :desc).first or raise 'no token in play'
  count_before = organization.api_tokens.count

  page.driver.post(api_tokens_path, params: { api_token: { name: 'ci-runner' } })
  expect(page.status_code).to eq(403)

  page.driver.post(revoke_api_token_path(token))
  expect(page.status_code).to eq(403)

  expect(organization.api_tokens.count).to eq(count_before)
  expect(token.reload.revoked_at).to be_nil
end

# PRD-0007 DEV-0005 / issue #191 — a revoked token stops authenticating the
# machine API immediately. The Background mints its digest-only ci-runner
# with the plaintext discarded, and later @javascript scenarios leave rows
# behind (truncation strategy), so the Given mints a known-plaintext token
# for the org under the scenario's own name and revokes it through the real
# command (the same one the web revoke control drives); the When presents
# THAT plaintext and the Then asserts 401 — proving the revoked row's own
# digest can no longer authenticate (TokenAuthentication looks up only
# ApiToken.active).
Given(/^"([^"]+)" has been revoked by its owner$/) do |token_name|
  organization = @api_test_org or raise 'no feature-background organization in play'
  @plain_api_token = Identity::ApiToken.generate_plaintext
  token = Identity::ApiToken.create!(
    organization: organization,
    name: token_name,
    token_digest: Identity::ApiToken.digest(@plain_api_token)
  )
  result = Identity::RevokeApiTokenCommand.call(api_token: token)
  raise "revocation failed: #{result.errors.inspect}" unless result.success?
end

When(/^I GET \/api\/v1\/chromosomes with the revoked token$/) do
  token = @plain_api_token or raise 'no revoked token in play'
  page.driver.header('Authorization', "Bearer #{token}")
  page.driver.get('/api/v1/chromosomes')
end

# PRD-0007 DEV-0008 / issue #194 — an organization with no tokens sees an
# empty state. The Given mints the org (find_or_create, adopting the unique
# name across features) and proves no token rows ride along; the Then asserts
# the guidance copy that routes owners to the create surface right above the
# list.
Given(/^organization "([^"]+)" has no API tokens$/) do |org_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  raise "organization #{org_name} unexpectedly owns API tokens" unless organization.api_tokens.none?
end

Then(/^I see guidance to create the first API token$/) do
  expect(page).to have_content('No API tokens yet')
  expect(page).to have_content(/create your first token/i)
end

# --- stacked box rhythm (issue #205) ---

# Every VISIBLE box panel on the page, with the rhythm it carries (its computed
# bottom margin) and the real gap to the box below it. The page header already
# owns mb-6 (the DESIGN.md lg step, 24px); box panels rendered with no bottom
# rhythm at all, so the create card sat flush against the token table. Only
# real layout can measure the boxes apart (rack_test renders no layout).
Then(/^the stacked boxes on the page are separated by the section rhythm$/) do
  boxes = page.evaluate_script(<<~JS)
    (() => {
      const boxes = Array.from(document.querySelectorAll('.card, .table-wrap, .empty-state'))
        .filter((box) => box.offsetParent !== null);
      return boxes.map((box, index) => {
        const next = boxes[index + 1];
        const bottom = box.getBoundingClientRect().bottom;
        // Only vertically-ordered pairs are stacked seams: boxes side by side in
        // a grid/flex row are spaced by that container, not by this rhythm.
        const stacked = next && next.getBoundingClientRect().top >= bottom;
        return {
          margin: Math.round(parseFloat(getComputedStyle(box).marginBottom)),
          gap: stacked ? Math.round(next.getBoundingClientRect().top - bottom) : null
        };
      });
    })()
  JS

  # Non-vacuity: the page renders its stacked boxes, and a box that carries no
  # rhythm at all reports a computed margin of 0.
  expect(boxes.size).to be >= 2, "expected the page's stacked boxes, got #{boxes.inspect}"
  expect(boxes.pluck('margin').min).to be >= 24, "a box carries no section rhythm: #{boxes.inspect}"

  boxes.each do |box|
    next if box['gap'].nil?

    message = "two boxes sit #{box['gap']}px apart — under the 24px rhythm: #{boxes.inspect}"
    expect(box['gap']).to be >= 24, message
  end
end
