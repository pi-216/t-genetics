# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::CreateApiTokenCommand do
  subject(:call) { described_class.call(organization:, name:) }

  let(:organization) { FactoryBot.create(:organization) }
  let(:name) { 'ci-runner' }

  describe 'success' do
    it 'creates an API token for the org and returns the plaintext once' do
      expect { call }.to change(Identity::ApiToken, :count).by(1)
      expect(call).to be_success
      expect(call.api_token).to be_persisted
      expect(call.api_token.organization).to eq(organization)
      expect(call.api_token.name).to eq('ci-runner')
      expect(call.plaintext_token).to be_present
    end

    it 'stores only a digest — never the plaintext' do
      call
      stored = Identity::ApiToken.last
      expect(stored.token_digest).not_to eq(call.plaintext_token)
      expect(stored.token_digest).to eq(Identity::ApiToken.digest(call.plaintext_token))
      expect(Identity::ApiToken.column_names).not_to include('token')
    end
  end

  describe 'failure' do
    let(:name) { '   ' }

    it 'fails and creates no token when the name is blank' do
      expect { call }.not_to change(Identity::ApiToken, :count)
      expect(call).to be_failure
      expect(call.error.to_s).to include("Name can't be blank")
      expect(call.plaintext_token).to be_nil
    end
  end
end
