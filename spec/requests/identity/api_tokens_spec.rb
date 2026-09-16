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

      it 'creates a digest-only token and redirects to the token page' do
        expect do
          post api_tokens_path, params: { api_token: { name: 'ci-runner' } }
        end.to change(Identity::ApiToken, :count).by(1)

        expect(response).to redirect_to(api_tokens_index_path)
        expect(Identity::ApiToken.last).to have_attributes(
          organization:,
          name: 'ci-runner',
          token_digest: match(/\A[0-9a-f]{64}\z/)
        )
      end

      # PRD-0007 DEV-0003 — the one-time reveal lands on the management page
      # (the create surface moved off the settings page).
      it 'shows the plaintext exactly once and never persists it raw' do
        post api_tokens_path, params: { api_token: { name: 'ci-runner' } }
        follow_redirect!
        expect(response).to have_http_status(:ok)
        plaintext = response.body[%r{<code[^>]*id="token_plaintext_value"[^>]*>([^<]+)</code>}, 1]
        expect(plaintext).to be_present

        # Shown exactly once on the creation response and never stored raw —
        # the plaintext itself never appears among the persisted digests.
        expect(response.body.scan(plaintext).size).to eq(1)
        expect(Identity::ApiToken.pluck(:token_digest)).not_to include(plaintext)

        # Not re-shown on a later visit (flash consumed by the redirect).
        get api_tokens_index_path
        expect(response.body).not_to include(plaintext)
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

      # Only active tokens carry a revoke control (issue #190); a revoked row
      # renders no form — the revoke affordance is exactly one submit button
      # (the "Revoke" column header is a <th>, not a button).
      it 'renders the revoke control for active tokens only' do
        get api_tokens_index_path

        expect(response.body.scan('>Revoke</button>').size).to eq(1)
      end

      it 'renders the create-token form on the management page' do
        get api_tokens_index_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('id="api_token_name"')
        expect(response.body).to include('Create token')
      end

      # The failure surface moved with the create form (PRD-0007 issue #189):
      # a rejected create must still land somewhere visible on the page the
      # redirect sends the owner to — never a silent flash.
      it 'surfaces a rejected create as an alert on the management page' do
        expect do
          post api_tokens_path, params: { api_token: { name: '' } }
        end.not_to change(Identity::ApiToken, :count)

        follow_redirect!

        expect(response).to have_http_status(:ok)
        expect(response.body).to match(/can(&#39;|')t be blank/)
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

  # PRD-0007 DEV-0004 / issue #190 — the owner revokes an active token.
  # Revocation is immediate: TokenAuthentication authenticates only
  # non-revoked tokens (ApiToken.active), so a stamped revoked_at kills API
  # access on the next request. The revoke POST is owner-only; a cross-org
  # id answers 404 — a token outside the current organization is
  # indistinguishable from one that does not exist (PRD-0002 red line).
  describe 'revocation' do
    let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }

    def sign_in_as_owner
      owner = FactoryBot.create(:user)
      FactoryBot.create(:org_membership, user: owner, organization:,
                                         role: Identity::OrgMembership::OWNER_ROLE)
      post login_path, params: { identity_user: { email: owner.email, password: owner.password } }
    end

    it 'revokes an active token and redirects to the management page' do
      token = FactoryBot.create(:api_token, organization:, name: 'ci-runner')
      sign_in_as_owner

      post revoke_api_token_path(token)

      expect(response).to redirect_to(api_tokens_index_path)
      expect(token.reload).to be_revoked
    end

    it 're-revoking an already-revoked token stays revoked (no error)' do
      token = FactoryBot.create(:api_token, organization:, name: 'ci-runner')
      sign_in_as_owner

      post revoke_api_token_path(token)
      post revoke_api_token_path(token)

      expect(response).to redirect_to(api_tokens_index_path)
      expect(token.reload).to be_revoked
    end

    it 'never shows plaintext or the raw digest after revocation' do
      token = FactoryBot.create(:api_token, organization:, name: 'ci-runner')
      sign_in_as_owner

      post revoke_api_token_path(token)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('Copy this token now')
      expect(response.body).not_to include(token.token_digest)
    end

    it 'surfaces the alert when revocation fails to persist' do
      token = FactoryBot.create(:api_token, organization:, name: 'ci-runner')
      sign_in_as_owner
      failing = Identity::RevokeApiTokenCommand.build_context(api_token: token, error: 'cannot revoke')
      allow(Identity::RevokeApiTokenCommand).to receive(:call).and_return(failing)

      post revoke_api_token_path(token)
      follow_redirect!

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('cannot revoke')
      expect(token.reload).not_to be_revoked
    end

    context 'when signed in as a member' do
      it 'is forbidden and revokes nothing' do
        token = FactoryBot.create(:api_token, organization:, name: 'ci-runner')
        member = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user: member, organization:)
        post login_path,
             params: { identity_user: { email: member.email, password: member.password } }

        post revoke_api_token_path(token)

        expect(response).to have_http_status(:forbidden)
        expect(token.reload).not_to be_revoked
      end
    end

    context 'with another organization’s token' do
      it 'answers 404 and revokes nothing' do
        other_org = FactoryBot.create(:organization, name: 'Other Labs')
        other_token = FactoryBot.create(:api_token, organization: other_org, name: 'other-runner')
        sign_in_as_owner

        post revoke_api_token_path(other_token)

        expect(response).to have_http_status(:not_found)
        expect(other_token.reload).not_to be_revoked
      end
    end
  end
end
