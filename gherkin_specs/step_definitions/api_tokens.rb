# frozen_string_literal: true

# Step definitions for PRD-0005 DEV-0001 — the owner creates an API token
# (issue #36) and sees the plaintext exactly once. The org/chromosome
# ownership step is shared by the whole feature Background; the create flow
# drives the real web UI (Capybara / rack_test) like the identity features.
# Factory truth: :user / :organization / :org_membership factories in
# spec/factories/.

Given(/^organization "([^"]+)" owns chromosome "([^"]+)"$/) do |org_name, chromosome_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  organization.chromosomes.find_or_create_by!(name: chromosome_name)
end

When(/^I create an API token named "([^"]+)" for "([^"]+)"$/) do |token_name, org_name|
  organization = Identity::Organization.find_by!(name: org_name)
  owner_email = "owner-#{organization.name.parameterize}@example.com"
  user = Identity::User.find_or_create_by!(email: owner_email) do |new_user|
    new_user.password = 's3cret-password'
  end
  Identity::OrgMembership.find_or_create_by!(user:, organization:) do |membership|
    membership.role = Identity::OrgMembership::OWNER_ROLE
  end

  visit login_path
  fill_in 'Email', with: user.email
  fill_in 'Password', with: user.password
  click_button 'Sign in'

  visit settings_path
  fill_in 'Token name', with: token_name
  click_button 'Create token'

  @plaintext_token = page.find('#token_plaintext_value').text.strip
end

Then(/^I see the plaintext token exactly once$/) do
  expect(@plaintext_token).to be_present

  # Shown exactly once on the creation response.
  expect(page.body.scan(@plaintext_token).size).to eq(1)

  # Digest-only storage — the plaintext never lands in the database.
  expect(Identity::ApiToken.pluck(:token_digest)).not_to include(@plaintext_token)

  # Not re-shown on a later visit.
  visit settings_path
  expect(page.body).not_to include(@plaintext_token)
end

# DEV-0002 (issue #37) — a member cannot create API tokens. The token form is
# hidden from members (owner-only settings render), so the honest attempt is a
# crafted POST straight at the endpoint; the owner-only controller guard must
# answer 403 and create no row.
When(/^I try to create an API token$/) do
  page.driver.post(api_tokens_path, params: { api_token: { name: 'ci-runner' } })
end

Then(/^I receive a forbidden response and no token is created$/) do
  expect(page.status_code).to eq(403)
  expect(Identity::ApiToken.count).to eq(0)
end
