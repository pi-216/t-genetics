# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Registrations', type: :request do
  let(:valid_params) do
    { identity_user: { email: 'ada@example.com', password: 'S3cretPass!', organization_name: 'Loop Labs' } }
  end

  describe 'GET /register' do
    it 'renders the sign-up form' do
      get register_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Create your account')
    end
  end

  describe 'POST /register' do
    context 'with valid params' do
      it 'creates a user, organization, and owner membership' do
        expect { post register_path, params: valid_params }
          .to change(Identity::User, :count).by(1)
          .and change(Identity::Organization, :count).by(1)
          .and change(Identity::OrgMembership, :count).by(1)

        membership = Identity::OrgMembership.last
        expect(membership.role).to eq('owner')
        expect(membership.user.email).to eq('ada@example.com')
        expect(membership.organization.name).to eq('Loop Labs')
      end

      it 'signs me in and redirects to the root path' do
        post register_path, params: valid_params

        expect(response).to redirect_to(root_path)
        expect(session[:user_id]).to eq(Identity::User.last.id)
      end
    end

    context 'with invalid params' do
      it 'renders 422 and creates nothing when email is blank' do
        expect do
          post register_path, params: { identity_user: { email: '', password: 'S3cretPass!', organization_name: 'Loop Labs' } }
        end.not_to change(Identity::User, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(session[:user_id]).to be_nil
      end

      it 'renders 422 and creates nothing when the org name is blank' do
        expect do
          post register_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!', organization_name: '' } }
        end.not_to change(Identity::Organization, :count)

        expect(response).to have_http_status(:unprocessable_content)
        expect(Identity::User.count).to eq(0)
        expect(Identity::OrgMembership.count).to eq(0)
      end
    end
  end
end
