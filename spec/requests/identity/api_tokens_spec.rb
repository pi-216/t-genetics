# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API token creation', type: :request do
  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }

  def sign_in_as(user)
    post login_path, params: { identity_user: { email: user.email, password: user.password } }
  end

  context 'when signed in as the organization owner' do
    let(:owner) do
      FactoryBot.create(:user).tap do |user|
        FactoryBot.create(:org_membership, user:, organization:,
                                           role: Identity::OrgMembership::OWNER_ROLE)
      end
    end

    before { sign_in_as(owner) }

    it 'creates a digest-only token and redirects back to settings' do
      expect do
        post api_tokens_path, params: { api_token: { name: 'ci-runner' } }
      end.to change(Identity::ApiToken, :count).by(1)

      expect(response).to redirect_to(settings_path)
      expect(Identity::ApiToken.last).to have_attributes(
        organization:,
        name: 'ci-runner',
        token_digest: match(/\A[0-9a-f]{64}\z/)
      )
    end
  end

  context 'when signed in as a member' do
    it 'is forbidden and creates no token' do
      member = FactoryBot.create(:user)
      FactoryBot.create(:org_membership, user: member, organization:)
      sign_in_as(member)

      expect do
        post api_tokens_path, params: { api_token: { name: 'ci-runner' } }
      end.not_to change(Identity::ApiToken, :count)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
