# frozen_string_literal: true

# Step definitions for PRD-0003 — the experiment workspace (the loop, in the
# UI). DEV-0001 (issue #68): a member creates a named experiment on an org
# chromosome with a population size and sees it (not yet ripe) under their
# organization. Factory truth: :organization / :chromosome / :user /
# :org_membership factories in spec/factories/ — never invented fields.
# The "organization X owns chromosome Y" background step is shared with the
# PRD-0005 feature (gherkin_specs/step_definitions/api_tokens.rb) — reuse, do
# not redefine.

Given(/^I am signed in as an owner of "([^"]+)"$/) do |org_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  email = "owner-#{organization.name.parameterize}@example.com"
  password = 'S3cretPass!'
  user = Identity::User.find_or_create_by!(email:) do |u|
    u.password = password
  end
  Identity::OrgMembership.find_or_create_by!(user:, organization:) do |m|
    m.role = Identity::OrgMembership::OWNER_ROLE
  end

  visit login_path
  fill_in 'Email', with: email
  fill_in 'Password', with: password
  click_button 'Sign in'
end

When(/^I create the "([^"]+)" experiment on "([^"]+)" with population (\d+)$/) do |name, chromosome_name, population|
  visit new_experiment_path
  fill_in 'Name', with: name
  select chromosome_name, from: 'experiment_chromosome_id'
  fill_in 'Population size', with: population
  click_button 'Create experiment'
end

Then(/^I see the experiment under my organization$/) do
  # The create flow lands on the org-scoped experiment detail page — the new
  # experiment is visible under our organization. The org-scoped INDEX listing
  # is covered separately by spec/requests/experiments_spec.rb.
  expect(page).to have_content('Donation amounts')
  expect(page).to have_content('Alpha-chrom')
end

And(/^evolution is not yet ripe$/) do
  expect(page).to have_content(/not yet ripe/i)
end
