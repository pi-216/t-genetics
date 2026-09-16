# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::RevokeApiTokenCommand do
  subject(:call) { described_class.call(api_token: token) }

  let(:token) { FactoryBot.create(:api_token, name: 'ci-runner') }

  describe 'success' do
    it 'revokes an active token by stamping revoked_at' do
      expect(call).to be_success
      expect(call.api_token).to eq(token)
      expect(token.reload).to be_revoked
      expect(token.revoked_at).to be_present
    end

    it 'leaves the credential material untouched (digest-only, unchanged)' do
      digest_before = token.token_digest
      call
      expect(token.reload.token_digest).to eq(digest_before)
    end
  end

  describe 'idempotency' do
    it 're-revoking an already-revoked token stays revoked without error' do
      token.update!(revoked_at: 1.day.ago)

      expect(call).to be_success
      expect(token.reload).to be_revoked
    end
  end

  describe 'failure' do
    it 'fails without stamping revoked_at when the row cannot save' do
      allow(token).to receive(:save).and_return(false)

      expect(call).to be_failure
      expect(call.error).to be_present
      expect(token.reload).not_to be_revoked
    end
  end
end
