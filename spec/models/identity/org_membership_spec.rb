# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::OrgMembership do
  subject { FactoryBot.create(:org_membership) }

  describe 'associations' do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_inclusion_of(:role).in_array(Identity::OrgMembership::ROLES) }
    it { is_expected.to validate_presence_of(:role) }
    # v1: one org per user (PRD-0002 A2) — enforced here and at the DB level.

    it { is_expected.to validate_uniqueness_of(:user_id) }
  end

  describe 'roles' do
    it 'allows only flat owner/member roles' do
      expect(Identity::OrgMembership::ROLES).to contain_exactly('owner', 'member')
    end
  end
end
