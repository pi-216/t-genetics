# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::JoinCommand do
  subject(:call) { described_class.call(invite_code: invite_code, email: email, password: password) }

  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let(:invite_code) { 'INVITE-ABC' }
  let(:email) { 'bob@example.com' }
  let(:password) { 'S3cretPass!' }

  before { FactoryBot.create(:invite_code, organization: organization, code: 'INVITE-ABC') }

  describe 'success' do
    it 'creates a user and a member membership in the code\'s organization' do
      expect { call }
        .to change(Identity::User, :count).by(1)
        .and change(Identity::OrgMembership, :count).by(1)

      expect(call.user.email).to eq('bob@example.com')
      expect(call.organization).to eq(organization)
      expect(call.membership.role).to eq(Identity::OrgMembership::MEMBER_ROLE)
    end

    it 'never grants an owner role' do
      call
      expect(Identity::OrgMembership.last.role).to eq(Identity::OrgMembership::MEMBER_ROLE)
    end

    context 'when the invite code is submitted in a different case' do
      let(:invite_code) { 'invite-abc' }

      it 'still joins successfully to the code\'s organization' do
        expect(call).to be_success
        expect(call.organization).to eq(organization)
      end
    end
  end

  describe 'failure' do
    context 'when the invite code does not exist' do
      let(:invite_code) { 'NOPE-123' }

      it 'is a failure, creates nothing, and reports the invalid code' do
        expect(call).to be_failure
        expect(Identity::User.count).to eq(0)
        expect(Identity::OrgMembership.count).to eq(0)
        expect(call.full_error_message).to include('Invalid invite code')
      end
    end

    context 'when the email is already taken' do
      before { FactoryBot.create(:user, email: 'bob@example.com') }

      it 'is a failure and creates no membership' do
        expect(call).to be_failure
        expect(Identity::OrgMembership.count).to eq(0)
        expect(call.full_error_message).to include('Email has already been taken')
      end
    end

    context 'when a concurrent insert wins the unique-index race' do
      # The valid? gate passed, but the DB insert hits a uniqueness constraint
      # (duplicate email). The command must degrade to a clean failure, not
      # raise a RecordNotUnique up to the controller (which would 500).
      it 'is a failure with a clean error instead of an exception' do
        racing_user = Identity::User.new(email: email, password: password)
        allow(racing_user).to receive(:save!).and_raise(ActiveRecord::RecordNotUnique, 'duplicate key value violates unique constraint')
        allow(Identity::User).to receive(:new).and_return(racing_user)

        expect(call).to be_failure
        expect(Identity::OrgMembership.count).to eq(0)
        expect(call.full_error_message).not_to be_blank
      end
    end
  end
end
