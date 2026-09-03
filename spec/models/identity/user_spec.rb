# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::User do
  subject { FactoryBot.create(:user) }

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

  describe 'password' do
    it 'hashes the password with bcrypt' do
      user = FactoryBot.create(:user, password: 'S3cretPass!')

      expect(user.authenticate('S3cretPass!')).to eq(user)
      expect(user.authenticate('wrong-password')).to be_falsey
      expect(user.password_digest).not_to include('S3cretPass!')
    end
  end
end
