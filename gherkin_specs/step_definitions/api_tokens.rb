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

# DEV-0003 (issue #38) — a valid token authenticates chromosome reads over the
# machine API. The token is created directly with a known plaintext (the web
# create flow shows it once, but the API steps need it in hand to build the
# Bearer header). The request goes through rack_test's driver with an
# Authorization header so the full routing + controller stack is exercised.
Given(/^"([^"]+)" has a valid API token$/) do |org_name|
  organization = Identity::Organization.find_by!(name: org_name)
  @plain_api_token = Identity::ApiToken.generate_plaintext
  Identity::ApiToken.create!(
    organization: organization,
    name: 'ci-runner',
    token_digest: Identity::ApiToken.digest(@plain_api_token)
  )
end

When(/^I GET \/api\/v1\/chromosomes with that token$/) do
  # rack_test driver: `header` normalizes to HTTP_AUTHORIZATION; a raw hash
  # passed to get() is taken as env verbatim and the case-sensitive
  # 'Authorization' key is not picked up by ActionDispatch.
  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.get('/api/v1/chromosomes')
end

Then(/^I receive a 200 response listing "([^"]+)"$/) do |chromosome_name|
  expect(page.status_code).to eq(200)
  expect(page.body).to include(chromosome_name)
end

# DEV-0004 (issue #39) — an invalid, missing, or revoked token is rejected.
# The org's revoked token is created up front so the request proves a revoked
# row cannot authenticate anything; the presented token is a plain wrong
# value and the machine API must answer 401 (the auth concern looks up only
# active digests). Missing-token and revoked-token 401 paths are pinned by
# the request spec (spec/requests/api/v1/token_chromosomes_spec.rb).
Given(/^"([^"]+)" has a revoked API token$/) do |org_name|
  organization = Identity::Organization.find_by!(name: org_name)
  Identity::ApiToken.create!(
    organization: organization,
    name: 'revoked-ci-runner',
    token_digest: Identity::ApiToken.digest(Identity::ApiToken.generate_plaintext),
    revoked_at: Time.current
  )
end

When(/^I GET \/api\/v1\/chromosomes with an invalid token$/) do
  page.driver.header('Authorization', 'Bearer invalid-not-a-real-token')
  page.driver.get('/api/v1/chromosomes')
end

Then(/^I receive a (\d+) response$/) do |status|
  expect(page.status_code).to eq(status.to_i)
end

# DEV-0005 (issue #40) — tokens are org-scoped. A token authenticates ONLY as
# its own organization: listing chromosomes with Beta's token must never
# disclose Loop Labs' chromosome, even though the endpoint only asks for the
# org by name in the step language. Org isolation is the machine-API red line
# (cross-org 404/never-data), enforced by TokenAuthentication#current_organization
# feeding the scoped query in Api::V1::ChromosomesController#index.
Given(/^organization "([^"]+)" owns no chromosomes$/) do |org_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  expect(organization.chromosomes.count).to eq(0)
end

When(/^I GET \/api\/v1\/chromosomes of "([^"]+)" using "([^"]+)"'s token$/) do |_query_org_name, token_org_name|
  token_org = Identity::Organization.find_by!(name: token_org_name)
  @plain_api_token = Identity::ApiToken.generate_plaintext
  Identity::ApiToken.create!(
    organization: token_org,
    name: 'ci-runner',
    token_digest: Identity::ApiToken.digest(@plain_api_token)
  )
  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.get('/api/v1/chromosomes')
end

Then(/^I do not see "([^"]+)"$/) do |chromosome_name|
  expect(page.status_code).to eq(200)
  expect(page.body).not_to include(chromosome_name)
end
