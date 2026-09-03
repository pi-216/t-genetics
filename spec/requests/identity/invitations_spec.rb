# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Invitations', type: :request do
  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let(:valid_params) do
    { identity_user: { invite_code: 'invite-abc', email: 'bob@example.com', password: 'S3cretPass!' } }
  end

  before { FactoryBot.create(:invite_code, organization: organization, code: 'INVITE-ABC') }

  describe 'GET /join' do
    it 'renders the join form' do
      get join_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Join an organization')
    end
  end

  describe 'POST /join' do
    context 'with a valid invite code' do
      it 'creates a user and a member membership in the code\'s organization' do
        expect { post join_path, params: valid_params }
          .to change(Identity::User, :count).by(1)
          .and change(Identity::OrgMembership, :count).by(1)

        user = Identity::User.find_by!(email: 'bob@example.com')
        membership = Identity::OrgMembership.find_by!(user: user)
        expect(membership.organization).to eq(organization)
        expect(membership.role).to eq(Identity::OrgMembership::MEMBER_ROLE)
      end

      it 'signs me in and redirects to the root path' do
        post join_path, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(session[:user_id]).to eq(Identity::User.find_by!(email: 'bob@example.com').id)
      end
    end

    context 'with an invalid invite code' do
      it 'renders 422 and creates nothing' do
        expect do
          post join_path, params: { identity_user: { invite_code: 'NOPE', email: 'bob@example.com', password: 'S3cretPass!' } }
        end.not_to change(Identity::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Identity::OrgMembership.count).to eq(0)
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with malformed params (identity_user is not a hash)' do
      it 'renders 422 and creates nothing rather than crashing' do
        expect do
          post join_path, params: { identity_user: 'garbage' }
        end.not_to change(Identity::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Identity::OrgMembership.count).to eq(0)
        expect(session[:user_id]).to be_nil
      end
    end

    context 'with an email that already has an account' do
      before { FactoryBot.create(:user, email: 'bob@example.com') }

      it 'renders 422 and creates no membership' do
        expect do
          post join_path, params: valid_params
        end.not_to change(Identity::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Identity::OrgMembership.count).to eq(0)
        expect(session[:user_id]).to be_nil
      end
    end
  end
end
