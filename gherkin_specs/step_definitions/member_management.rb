# frozen_string_literal: true

# Step definitions for DEV-0010 - the last owner cannot be removed or demoted.
Given(/^"([^"]+)" has one owner "([^"]+)" and a member "([^"]+)"$/) do |org_name, owner_email, member_email|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  owner = FactoryBot.create(:user, email: owner_email)
  member = FactoryBot.create(:user, email: member_email)
  FactoryBot.create(:org_membership, user: owner, organization: organization, role: Identity::OrgMembership::OWNER_ROLE)
  FactoryBot.create(:org_membership, user: member, organization: organization, role: Identity::OrgMembership::MEMBER_ROLE)
end

When(/^"([^"]+)" attempts to remove her own owner role$/) do |email|
  user = Identity::User.find_by!(email: email)
  membership = Identity::OrgMembership.find_by!(user: user)
  @last_owner_removal = Identity::RemoveMembershipCommand.call(membership: membership)
end

Then(/^the removal is rejected$/) do
  expect(@last_owner_removal).to be_failure
  expect(@last_owner_removal.full_error_message).to include('last owner')
end

And(/^"([^"]+)" remains the owner of "([^"]+)"$/) do |email, org_name|
  user = Identity::User.find_by!(email: email)
  organization = Identity::Organization.find_by!(name: org_name)
  membership = Identity::OrgMembership.find_by!(user: user, organization: organization)
  expect(membership).to be_persisted
  expect(membership.role).to eq(Identity::OrgMembership::OWNER_ROLE)
end
