# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::GenerateInviteCodeCommand do
  subject(:call) { described_class.call(organization:) }

  let(:organization) { FactoryBot.create(:organization) }

  describe 'success' do
    it 'generates an invite code for an org without one' do
      expect { call }.to change(Identity::InviteCode, :count).by(1)
      expect(call).to be_success
      expect(call.invite_code.organization).to eq(organization)
      expect(call.invite_code.code).to match(/\AINVITE-[A-Z0-9]{10}\z/)
    end

    it 'returns the existing code when the org already has one (idempotent)' do
      existing = FactoryBot.create(:invite_code, organization:)
      expect { call }.not_to change(Identity::InviteCode, :count)
      expect(call).to be_success
      expect(call.invite_code).to eq(existing)
    end
  end

  describe 'failure' do
    it 'is a failure when the org already has a code and the race copy is invalid' do
      FactoryBot.create(:invite_code, organization:)
      invalid_stub = instance_double(Identity::InviteCode, save: false, errors: ActiveModel::Errors.new(nil))
      allow(organization).to receive_messages(invite_code: nil, build_invite_code: invalid_stub)

      expect(call).to be_failure
      expect(call.error).to be_present
    end
  end
end
