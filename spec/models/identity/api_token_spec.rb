# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::ApiToken, type: :model do
  it 'belongs to an organization' do
    expect(FactoryBot.build(:api_token).organization).to be_present
  end

  it 'requires a name' do
    expect(FactoryBot.build(:api_token, name: '')).not_to be_valid
  end

  it 'requires a token digest' do
    expect(FactoryBot.build(:api_token, token_digest: '')).not_to be_valid
  end

  describe '.generate_plaintext' do
    it 'returns a non-empty random string' do
      expect(described_class.generate_plaintext).to be_present
    end

    it 'is unique across calls' do
      expect(described_class.generate_plaintext).not_to eq(described_class.generate_plaintext)
    end
  end

  describe '.digest' do
    it 'returns the SHA-256 hex digest of the plaintext' do
      plaintext = 'the-secret'
      expect(described_class.digest(plaintext)).to eq(Digest::SHA256.hexdigest(plaintext))
      expect(described_class.digest(plaintext).length).to eq(64)
    end
  end

  describe '#revoked?' do
    it 'is false while active and true once revoked' do
      token = FactoryBot.build(:api_token)
      expect(token).not_to be_revoked

      token.revoked_at = Time.current
      expect(token).to be_revoked
    end
  end
end
