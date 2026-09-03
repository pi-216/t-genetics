# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::RemoveMembershipCommand do
  subject(:call) { described_class.call(membership: membership) }

  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let(:owner) { FactoryBot.create(:user, email: 'ada@example.com') }
  let(:member) { FactoryBot.create(:user, email: 'bob@example.com') }
  let(:owner_membership) do
    FactoryBot.create(:org_membership,
                      user: owner,
                      organization: organization,
                      role: Identity::OrgMembership::OWNER_ROLE)
  end
  let(:member_membership) do
    FactoryBot.create(:org_membership,
                      user: member,
                      organization: organization,
                      role: Identity::OrgMembership::MEMBER_ROLE)
  end

  describe 'removing the only owner' do
    let(:membership) { owner_membership }

    it 'is rejected and the owner membership survives' do
      expect(call).to be_failure
      expect(owner_membership.reload).to be_persisted
      expect(owner_membership.reload.role).to eq(Identity::OrgMembership::OWNER_ROLE)
      expect(call.full_error_message).to include('last owner')
    end
  end

  describe 'removing a member' do
    let(:membership) { member_membership }

    it 'succeeds and destroys the membership' do
      membership
      expect { call }.to change(Identity::OrgMembership, :count).by(-1)
      expect(call).to be_success
    end
  end

  describe 'removing an owner when another owner exists' do
    let(:second_owner) { FactoryBot.create(:user, email: 'carol@example.com') }
    let(:second_owner_membership) do
      FactoryBot.create(:org_membership,
                        user: second_owner,
                        organization: organization,
                        role: Identity::OrgMembership::OWNER_ROLE)
    end
    let(:membership) { owner_membership }

    it 'succeeds - only the last owner is protected' do
      membership
      second_owner_membership
      expect { call }.to change(Identity::OrgMembership, :count).by(-1)
      expect(call).to be_success
    end
  end
end
