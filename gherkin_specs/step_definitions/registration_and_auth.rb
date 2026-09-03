# frozen_string_literal: true

# Step definitions for PRD-0002 — org sign-up (DEV-0001) and duplicate-email
# rejection (DEV-0002). Behavior-driven through the real web sign-up flow
# (Capybara / rack_test). Factory truth: :user / :organization /
# :org_membership factories live in spec/factories/.

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

Given(/^a user exists with email "([^"]+)"$/) do |email|
  FactoryBot.create(:user, email: email)
end

# DEV-0002 — a failed duplicate-email sign-up leaves no new records and
# shows the real validation error rendered at the controller layer.
Then(/^I see a validation error about the email being taken$/) do
  expect(page).to have_css('#error_explanation')
  expect(page).to have_content('Email has already been taken')
end

And(/^no new account or organization is created$/) do
  expect(Identity::User.count).to eq(1) # only the pre-existing user
  expect(Identity::Organization.count).to eq(0)
  expect(Identity::OrgMembership.count).to eq(0)
  expect(page.driver.request.session[:user_id]).to be_nil
end

# --- DEV-0003 — signing in with valid credentials establishes a session. ---#
Given(/^a user exists with email "([^"]+)" and password "([^"]+)"$/) do |email, password|
  FactoryBot.create(:user, email:, password:)
end

When(/^I sign in with email "([^"]+)" and password "([^"]+)"$/) do |email, password|
  @signed_in_email = email
  visit login_path
  fill_in 'Email', with: email
  fill_in 'Password', with: password
  click_button 'Sign in'
end

Then(/^I am signed in$/) do
  user = Identity::User.find_by!(email: @signed_in_email)
  expect(page.driver.request.session[:user_id]).to eq(user.id)
  expect(page).to have_current_path(root_path)
end

# --- DEV-0004 — signing in with invalid credentials fails safely. ---#
Then(/^I am not signed in$/) do
  expect(page.driver.request.session[:user_id]).to be_nil
  expect(page).to have_current_path(login_path)
  expect(page.status_code).to eq(422)
end

And(/^I see a generic invalid-credentials error$/) do
  expect(page).to have_css('#error_explanation')
  expect(page).to have_content('Invalid email or password')
end
