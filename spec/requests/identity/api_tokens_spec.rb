# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API tokens', type: :request do
  describe 'creation' do
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

  # PRD-0007 DEV-0001 / issue #187 — the dedicated token management page. The
  # owner opens a page listing every org token (active and revoked) with its
  # status; a member gets 403 and sees nothing (flat roles — owner-only
  # management, PRD-0005/0002 ruling).
  describe 'dedicated management page' do
    let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }

    before do
      FactoryBot.create(:api_token, organization:, name: 'ci-runner')
      FactoryBot.create(:api_token, organization:, name: 'old-runner', revoked_at: Time.current)
      # Cross-org red line: another org's token must never appear on this page.
      other_org = FactoryBot.create(:organization, name: 'Other Labs')
      FactoryBot.create(:api_token, organization: other_org, name: 'other-runner')
    end

    context 'when signed in as the organization owner' do
      before do
        owner = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user: owner, organization:,
                                           role: Identity::OrgMembership::OWNER_ROLE)
        post login_path, params: { identity_user: { email: owner.email, password: owner.password } }
      end

      it 'lists every org token with its status' do
        get api_tokens_index_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('ci-runner')
        expect(response.body).to include('Active')
        expect(response.body).to include('old-runner')
        expect(response.body).to include('Revoked')
        expect(response.body).not_to include('other-runner')
      end
    end

    context 'when signed in as a member' do
      before do
        member = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user: member, organization:)
        post login_path,
             params: { identity_user: { email: member.email, password: member.password } }
      end

      it 'is forbidden' do
        get api_tokens_index_path

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  # PRD-0007 DEV-0002 / issue #188 — the token management page is reachable
  # from the signed-in navigation. The shared layout renders the nav entry
  # only for the org owner (flat roles: a member cannot see token
  # management, PRD-0007 edge-case ruling).
  describe 'navigation entry' do
    let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }

    context 'when signed in as the organization owner' do
      it 'renders the token management link in the shared navigation' do
        owner = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user: owner, organization:,
                                           role: Identity::OrgMembership::OWNER_ROLE)
        post login_path, params: { identity_user: { email: owner.email, password: owner.password } }

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('API tokens')
        expect(response.body).to include('/organization/api_tokens')
      end
    end

    context 'when signed in as a member' do
      it 'does not render the token management link' do
        member = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user: member, organization:,
                                           role: Identity::OrgMembership::MEMBER_ROLE)
        post login_path,
             params: { identity_user: { email: member.email, password: member.password } }

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('API tokens')
        expect(response.body).not_to include('/organization/api_tokens')
      end
    end

    context 'when signed in as a user with no org membership' do
      it 'renders the layout without the token management link' do
        orphan = FactoryBot.create(:user)
        post login_path, params: { identity_user: { email: orphan.email, password: orphan.password } }

        get root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include('API tokens')
        expect(response.body).not_to include('/organization/api_tokens')
      end
    end
  end
end
