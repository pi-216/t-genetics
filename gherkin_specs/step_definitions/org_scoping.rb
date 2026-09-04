# frozen_string_literal: true

# Step definitions for DEV-0009 — Org A's user cannot access Org B's
# chromosomes (cross-org 404, never data). Factory truth: :organization /
# :user / :org_membership / :chromosome factories in spec/factories/.

Given(/^organization "([^"]+)" owns a chromosome named "([^"]+)"$/) do |org_name, chromosome_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  organization.chromosomes.find_or_create_by!(name: chromosome_name)
end

Given(/^organization "([^"]+)" has a user with email "([^"]+)"$/) do |org_name, email|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  user = FactoryBot.create(:user, email:)
  FactoryBot.create(:org_membership, user:, organization:)
end

When(/^the user "([^"]+)" visits the chromosome "([^"]+)"$/) do |email, chromosome_name|
  user = Identity::User.find_by!(email:)
  visit login_path
  fill_in 'Email', with: user.email
  fill_in 'Password', with: user.password
  click_button 'Sign in'

  chromosome = Chromosome.find_by!(name: chromosome_name)
  visit chromosome_path(chromosome)
end

# DEV-0004 (issue #80) — the current session (already signed in via a Given
# such as "I am signed in as an owner of organization ...") visits a named
# chromosome directly. Cross-org access must answer 404 via the controller's
# org-scoped lookup — never disclose another org's row.
When(/^I visit the chromosome "([^"]+)"$/) do |chromosome_name|
  chromosome = Chromosome.find_by!(name: chromosome_name)
  visit chromosome_path(chromosome)
end

Then(/^I receive a not-found or forbidden response$/) do
  expect(page.status_code).to eq(404)
end

And(/^the chromosome is not disclosed$/) do
  expect(page.body).not_to include('Alpha-chrom')
end
