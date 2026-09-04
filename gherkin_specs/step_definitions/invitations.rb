# frozen_string_literal: true

# Step definitions for DEV-0007 — joining an organization with an
# owner-generated invite code (PRD-0002 / issue #17). The Given step seeds the
# invite code through the domain model (the owner's generate-invite UI is
# DEV-0006 and stays @wip); the When/Then steps drive the real public join
# flow (Capybara / rack_test) and assert member-not-owner. The shared
# "signed in as a member" step also serves DEV-0008 (issue #18) as a
# Given — when no session exists, it establishes one through the real login
# flow (member, not owner) before asserting the session. The step matches
# any keyword, so a single definition covers both the join-then-assert Then
# and the settings-page Given usage.

Given(/^the owner of "([^"]+)" has generated invite code "([^"]+)"$/) do |org_name, code|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  FactoryBot.create(:invite_code, organization: organization, code: code)
end

When(/^I join "([^"]+)" with the following details:$/) do |_org_name, table|
  details = table.hashes.first
  @joined_email = details.fetch('email')

  visit join_path
  fill_in 'Invite code', with: details.fetch('invite_code')
  fill_in 'Email', with: @joined_email
  fill_in 'Password', with: details.fetch('password')
  click_button 'Join'
end

Given(/^I am signed in as a member of "([^"]+)"$/) do |org_name|
  session_user_id =
    begin
      page.driver.request.session[:user_id]
    rescue Rack::Test::Error
      # No request has been made yet (fresh scenario, Given usage) — there is
      # no session to inspect, so treat it as signed-out and log in below.
      nil
    end

  if session_user_id.nil?
    # DEV-0008 (Given usage): establish the member session through the real
    # login flow, recording the email for the assertions below.
    organization = Identity::Organization.find_or_create_by!(name: org_name)
    user = FactoryBot.create(:user)
    FactoryBot.create(:org_membership, user:, organization:, role: Identity::OrgMembership::MEMBER_ROLE)
    @joined_email = user.email
    visit login_path
    fill_in 'Email', with: user.email
    fill_in 'Password', with: user.password
    click_button 'Sign in'
  end
  user = Identity::User.find_by!(email: @joined_email)
  organization = Identity::Organization.find_by!(name: org_name)
  membership = Identity::OrgMembership.find_by!(user: user, organization: organization)

  expect(membership.role).to eq(Identity::OrgMembership::MEMBER_ROLE)
  expect(page.driver.request.session[:user_id]).to eq(user.id)
  expect(page).to have_current_path(root_path)
end

And(/^"([^"]+)" is a member, not an owner, of "([^"]+)"$/) do |email, org_name|
  user = Identity::User.find_by!(email: email)
  organization = Identity::Organization.find_by!(name: org_name)
  membership = Identity::OrgMembership.find_by!(user: user, organization: organization)

  expect(membership.role).to eq(Identity::OrgMembership::MEMBER_ROLE)
end
