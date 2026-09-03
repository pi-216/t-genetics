# frozen_string_literal: true

require 'rails_helper'

# Organization settings surface (PRD-0002 DEV-0008 / issue #18).
# The page exists for any signed-in org member; the member-management and
# token-management sections render owner-only — a member must never see
# them (flat owner/member roles; owner-only management per PRD-0002).
RSpec.describe 'Organization settings', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }

  describe 'GET /settings' do
    context 'when signed in as a member' do
      before { sign_in_as(organization: org) }

      it 'shows the organization name' do
        get settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Loop Labs')
      end

      it 'does not show member management or token management' do
        get settings_path

        expect(response.body).not_to include('Member management')
        expect(response.body).not_to include('Token management')
      end
    end

    context 'when signed in as an owner' do
      before do
        user = FactoryBot.create(:user)
        FactoryBot.create(:org_membership, user:, organization: org, role: Identity::OrgMembership::OWNER_ROLE)
        post login_path, params: { identity_user: { email: user.email, password: user.password } }
      end

      it 'shows the member-management and token-management sections' do
        get settings_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Member management')
        expect(response.body).to include('Token management')
      end
    end

    context 'when anonymous' do
      it 'redirects to the sign-in page' do
        get settings_path

        expect(response).to redirect_to(login_path)
      end
    end
  end
end
