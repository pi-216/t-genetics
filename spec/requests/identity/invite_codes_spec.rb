# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invite codes', type: :request do
  let(:organization) { FactoryBot.create(:organization) }
  let(:owner) { FactoryBot.create(:user) }
  let(:member) { FactoryBot.create(:user) }

  before do
    FactoryBot.create(:org_membership, user: owner, organization:, role: Identity::OrgMembership::OWNER_ROLE)
    FactoryBot.create(:org_membership, user: member, organization:)
  end

  def sign_in_as(user)
    post login_path, params: { identity_user: { email: user.email, password: user.password } }
  end

  describe 'GET /organization/invite_code' do
    context 'when signed in as the owner' do
      before { sign_in_as(owner) }

      it 'renders the invite-code page' do
        get organization_invite_code_path
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('Organization invite')
      end

      it 'shows the existing code when the org has one' do
        FactoryBot.create(:invite_code, organization:)
        get organization_invite_code_path
        expect(response.body).to include(Identity::InviteCode.last.code)
      end
    end

    context 'when signed in as a member' do
      before { sign_in_as(member) }

      it 'denies access with 403' do
        get organization_invite_code_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'denies access with 403' do
        get organization_invite_code_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /organization/invite_code' do
    context 'when signed in as the owner' do
      before { sign_in_as(owner) }

      it 'generates an invite code and redirects back' do
        expect { post organization_invite_code_path }.to change(Identity::InviteCode, :count).by(1)
        expect(response).to redirect_to(organization_invite_code_path)
      end

      it 'does not create a second code when one exists' do
        FactoryBot.create(:invite_code, organization:)
        expect { post organization_invite_code_path }.not_to change(Identity::InviteCode, :count)
        expect(response).to redirect_to(organization_invite_code_path)
      end
    end

    context 'when signed in as a member' do
      before { sign_in_as(member) }

      it 'denies with 403 and creates nothing' do
        expect { post organization_invite_code_path }.not_to change(Identity::InviteCode, :count)
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when unauthenticated' do
      it 'denies with 403' do
        post organization_invite_code_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
