# frozen_string_literal: true

# Step definitions for DEV-0006 — the owner can generate an invite code
# (PRD-0002 / issue #16). Drives the real owner page + generate action;
# the ownership guard itself is covered by request specs.

Given(/^I am signed in as the owner of "([^"]+)"$/) do |org_name|
  # find_or_create so a Background-pre-created org (PRD-0007 token feature)
  # is adopted instead of colliding on the unique name.
  @invite_org = Identity::Organization.find_or_create_by!(name: org_name)
  @invite_owner = FactoryBot.create(:user, email: 'owner@example.com', password: 'S3cretPass!')
  FactoryBot.create(:org_membership, user: @invite_owner, organization: @invite_org,
                                     role: Identity::OrgMembership::OWNER_ROLE)

  visit login_path
  fill_in 'Email', with: @invite_owner.email
  fill_in 'Password', with: 'S3cretPass!'
  click_button 'Sign in'
  # Real-browser (@javascript) runs: the login form is Turbo-driven, so
  # click_button returns while Devise's async sign-in fetch is still in
  # flight — a step that navigates next races it (no session on the next
  # request; owner-only actions then answer 403). Wait for the post-auth
  # destination first. No-op under rack_test, which is synchronous.
  expect(page).to have_current_path(experiments_path)
end

When(/^I generate an invite code for my organization$/) do
  visit organization_invite_code_path
  click_button 'Generate invite code'
end

Then(/^I see an invite code that lets others join "([^"]+)"$/) do |org_name|
  org = Identity::Organization.find_by!(name: org_name)
  displayed = page.find('.invite-code').text.strip
  expect(displayed).to match(/\AINVITE-[A-Z0-9]{10}\z/)
  expect(Identity::InviteCode.find_by!(organization: org).code).to eq(displayed)
end
