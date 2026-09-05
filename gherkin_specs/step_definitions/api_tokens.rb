# frozen_string_literal: true

# Step definitions for PRD-0005 DEV-0001 — the owner creates an API token
# (issue #36) and sees the plaintext exactly once. The org/chromosome
# ownership step is shared by the whole feature Background; the create flow
# drives the real web UI (Capybara / rack_test) like the identity features.
# Factory truth: :user / :organization / :org_membership factories in
# spec/factories/.

Given(/^organization "([^"]+)" owns chromosome "([^"]+)"$/) do |org_name, chromosome_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  # Remembered so later steps without an explicit org name (DEV-0006 create)
  # can target the feature background's organization.
  @api_test_org = organization
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

# DEV-0006 (issue #41) — machines create chromosomes with a token. The create
# mints a valid token for the feature background org when none is in hand
# (mirroring the DEV-0003 setup), POSTs the chromosome at the machine API with
# a Bearer header, and the follow-up Then re-lists with the same token so
# "appears in the API chromosome list" proves org-scoped persistence.
When(/^I create a chromosome named "([^"]+)" via the API$/) do |chromosome_name|
  organization = @api_test_org or raise 'no feature-background organization in play'
  @plain_api_token ||= begin
    token = Identity::ApiToken.generate_plaintext
    Identity::ApiToken.create!(
      organization: organization,
      name: 'ci-runner',
      token_digest: Identity::ApiToken.digest(token)
    )
    token
  end

  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post('/api/v1/chromosomes', chromosome: { name: chromosome_name })
end

Then(/^"([^"]+)" appears in the API chromosome list$/) do |chromosome_name|
  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.get('/api/v1/chromosomes')

  expect(page.status_code).to eq(200)
  expect(page.body).to include(chromosome_name)
end

# DEV-0007 (issue #42) — machines create experiments with a token. Mirrors the
# DEV-0006 create flow: mint a token for the feature-background org when none
# is in hand, POST the experiment at the machine API naming an org chromosome
# by id, and re-list with the same token so "appears in the API experiment
# list" proves org-scoped persistence (Experiments::Setup mints the initial
# generation + population under the hood).
When(/^I create an experiment on "([^"]+)" via the API$/) do |chromosome_name|
  organization = @api_test_org or raise 'no feature-background organization in play'
  chromosome = organization.chromosomes.find_by!(name: chromosome_name)
  @plain_api_token ||= begin
    token = Identity::ApiToken.generate_plaintext
    Identity::ApiToken.create!(
      organization: organization,
      name: 'ci-runner',
      token_digest: Identity::ApiToken.digest(token)
    )
    token
  end

  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post('/api/v1/experiments', experiment: { chromosome_id: chromosome.id })

  expect(page.status_code).to eq(201)
  @created_experiment = JSON.parse(page.body)
end

Then(/^the experiment appears in the API experiment list$/) do
  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.get('/api/v1/experiments')

  expect(page.status_code).to eq(200)
  listed_ids = JSON.parse(page.body).filter_map { |experiment| experiment['id'] }
  expect(listed_ids).to include(@created_experiment['id'])
end

# DEV-0010 (issue #45) — malformed payloads return validation errors. A
# malformed chromosome write (the rswag contract marks `name` required) answers
# 422 with a top-level "errors" key and creates no row. The missing-wrapper
# ParameterMissing variant is pinned to the same 422 contract by the base
# controller's rescue_from and the request spec
# (spec/requests/api/v1/chromosome_creation_spec.rb).
When(/^I send a malformed chromosome payload via the API$/) do
  organization = @api_test_org or raise 'no feature-background organization in play'
  @plain_api_token ||= begin
    token = Identity::ApiToken.generate_plaintext
    Identity::ApiToken.create!(
      organization: organization,
      name: 'ci-runner',
      token_digest: Identity::ApiToken.digest(token)
    )
    token
  end

  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post('/api/v1/chromosomes', chromosome: { name: '' })
end

Then(/^I receive a 422 response with error keys$/) do
  expect(page.status_code).to eq(422)
  body = JSON.parse(page.body)
  expect(body).to have_key('errors')
end

# DEV-0008 (issue #43) — machines request a suggestion with a token. The
# experiment must carry a populated generation for the loop to suggest from;
# the feature background chromosome is bare, so the step first gives it an
# allele (the value space), creates the experiment via the machine API
# (Experiments::Setup mints the generation + population from those alleles),
# then POSTs the suggestion request with the same Bearer token. "An organism
# with values" means the response carries the organism id plus a value per
# allele (Organism#to_hsh).
When(/^I request a suggestion for the experiment via the API$/) do
  organization = @api_test_org or raise 'no feature-background organization in play'
  chromosome = organization.chromosomes.find_by!(name: 'Alpha-chrom')
  if chromosome.alleles.empty?
    Allele.new_with_float(name: 'height', minimum: 0.0, maximum: 2.0).tap do |allele|
      allele.chromosome = chromosome
      allele.save!
    end
  end

  step 'I create an experiment on "Alpha-chrom" via the API'

  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post("/api/v1/experiments/#{@created_experiment['id']}/suggestion")
end

Then(/^I receive an organism with values$/) do
  expect(page.status_code).to eq(200)
  organism = JSON.parse(page.body)
  expect(organism).to include('id')
  expect(organism).to have_key('height')
end

# DEV-0009 (issue #44) — machines report a fitness outcome with a token. The
# Given mints the suggestion through the engine's RequestSuggestion command
# (the machine-API suggestion endpoint is DEV-0008 / issue #43), the When
# posts the ONE customer-reported fitness number for that suggestion, and the
# Then proves it landed on the same PerformanceLog the suggestion created —
# the only fitness-bearing input in the product.
# Shared Given (PRD-0005 DEV-0009 + PRD-0003 DEV-0004): the exact sentence is
# used by both the token-API feature and the web experiment workspace. The
# branch is the feature context: @signed_in_org is set only when the web
# sign-in step ran (experiment_workspace.rb), so the web flow drives the
# browser UI (whose When step lives in experiment_workspace.rb); otherwise the
# API flow drives the token suggestion endpoint.
Given(/^a suggestion has been requested for the experiment$/) do
  if @signed_in_org
    step 'I request a suggestion for the experiment'
    next
  end

  organization = @api_test_org or raise 'no feature-background organization in play'
  chromosome = organization.chromosomes.first or raise 'no chromosome in play'
  @plain_api_token ||= begin
    token = Identity::ApiToken.generate_plaintext
    Identity::ApiToken.create!(
      organization: organization,
      name: 'ci-runner',
      token_digest: Identity::ApiToken.digest(token)
    )
    token
  end

  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post('/api/v1/experiments', experiment: { chromosome_id: chromosome.id })
  expect(page.status_code).to eq(201)
  @created_experiment = JSON.parse(page.body)

  experiment = Experiment.find(@created_experiment['id'])
  suggestion = Experiments::RequestSuggestion.call(experiment: experiment)
  raise "suggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

  @suggestion_performance_log = suggestion.performance_log
end

When(/^I report fitness ([\d.]+) for that suggestion via the API$/) do |fitness|
  @reported_fitness = fitness.to_f
  page.driver.header('Authorization', "Bearer #{@plain_api_token}")
  page.driver.post(
    "/api/v1/performance_logs/#{@suggestion_performance_log.id}/outcome",
    { performance_log: { fitness_input_value: @reported_fitness } }.to_json,
    'CONTENT_TYPE' => 'application/json'
  )
  expect(page.status_code).to eq(200)
end

Then(/^the outcome is recorded on the performance log$/) do
  @suggestion_performance_log.reload
  expect(@suggestion_performance_log.fitness_input_value).to eq(@reported_fitness)
  expect(@suggestion_performance_log.outcome_recorded_at).to be_present
  expect(@suggestion_performance_log.suggested_at).to be_present
end
