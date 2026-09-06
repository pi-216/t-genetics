# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::User do
  subject(:user) { FactoryBot.create(:user) }

  describe 'associations' do
    it { is_expected.to have_one(:org_membership).dependent(:destroy) }
    it { is_expected.to have_one(:organization).through(:org_membership) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to allow_value('ada@example.com').for(:email) }
    it { is_expected.not_to allow_value('not-an-email').for(:email) }
  end

  describe 'Devise authentication (issue #118)' do
    it 'hashes the password with bcrypt and authenticates via valid_password?' do
      user = FactoryBot.create(:user, password: 'S3cretPass!')

      expect(user.valid_password?('S3cretPass!')).to be true
      expect(user.valid_password?('wrong-password')).to be false
      expect(user.encrypted_password).not_to include('S3cretPass!')
    end

    it 'exposes the recoverable and rememberable hooks' do
      expect(user).to respond_to(:reset_password_token)
      expect(user).to respond_to(:reset_password_sent_at)
      expect(user).to respond_to(:remember_created_at)
    end
  end
end
