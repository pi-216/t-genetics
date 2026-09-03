# frozen_string_literal: true

# Step definitions for PRD-0002 — org sign-up (DEV-0001).
# Behavior-driven through the real web sign-up flow (Capybara / rack_test).
# Factory truth: :user / :organization / :org_membership factories live in spec/factories/.

Given(/^I am on the sign-up page$/) do
  visit register_path
  expect(page).to have_content('Create your account')
end

When(/^I sign up with the following details:$/) do |table|
  details = table.hashes.first
  @signed_up_email = details.fetch('email')

  visit register_path
  fill_in 'Email', with: @signed_up_email
  fill_in 'Password', with: details.fetch('password')
  fill_in 'Organization', with: details.fetch('organization')
  click_button 'Create account'
end

Then(/^I am signed in with an organization named "([^"]+)"$/) do |name|
  user = Identity::User.find_by!(email: @signed_up_email)
  organization = Identity::Organization.find_by!(name: name)

  expect(Identity::OrgMembership.find_by!(user:, organization:)).to be_present
  expect(page.driver.request.session[:user_id]).to eq(user.id)

  expect(page).to have_current_path(root_path)
end

And(/^I am the owner of "([^"]+)"$/) do |name|
  user = Identity::User.find_by!(email: @signed_up_email)
  organization = Identity::Organization.find_by!(name: name)
  membership = Identity::OrgMembership.find_by!(user:, organization:)

  expect(membership.role).to eq(Identity::OrgMembership::OWNER_ROLE)
end
