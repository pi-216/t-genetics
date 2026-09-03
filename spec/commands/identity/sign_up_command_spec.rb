# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::SignUpCommand do
  subject(:call) { described_class.call(email:, password:, organization:) }

  let(:email) { 'ada@example.com' }
  let(:password) { 'S3cretPass!' }
  let(:organization) { 'Loop Labs' }

  describe 'success' do
    it 'creates a user, an organization, and an owner membership atomically' do
      expect { call }.to change(Identity::User, :count).by(1)
                                                       .and change(Identity::Organization, :count).by(1)
                                                                                                  .and change(Identity::OrgMembership, :count).by(1)

      expect(call.user.email).to eq('ada@example.com')
      expect(call.organization.name).to eq('Loop Labs')
      expect(call.membership.role).to eq(Identity::OrgMembership::OWNER_ROLE)
    end

    it 'normalizes email to lowercase' do
      call
      expect(Identity::User.last.email).to eq('ada@example.com')
    end

    it 'strips whitespace from the org name' do
      call
      expect(Identity::Organization.last.name).to eq('Loop Labs')
    end
  end

  describe 'failure' do
    context 'when the email is blank' do
      let(:email) { '' }

      it 'is a failure and creates nothing' do
        expect(call).to be_failure
        expect(Identity::User.count).to eq(0)
        expect(Identity::Organization.count).to eq(0)
        expect(Identity::OrgMembership.count).to eq(0)
      end
    end

    context 'when the email is already taken' do
      before { FactoryBot.create(:user, email: 'ada@example.com') }

      it 'is a failureand creates no org or membership' do
        expect(call).to be_failure
        expect(Identity::Organization.count).to eq(0)
        expect(Identity::OrgMembership.count).to eq(0)
        expect(call.full_error_message).to include('Email has already been taken')
      end
    end

    context 'when the org name is blank' do
      let(:organization) { '' }

      it 'is a failureand creates nothing' do
        expect(call).to be_failure
        expect(Identity::User.count).to eq(0)
        expect(Identity::Organization.count).to eq(0)
        expect(Identity::OrgMembership.count).to eq(0)
      end
    end
  end
end
