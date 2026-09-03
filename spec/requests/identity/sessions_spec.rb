# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Sessions', type: :request do
  let!(:user) { FactoryBot.create(:user, email: 'ada@example.com', password: 'S3cretPass!') }

  describe 'GET /login' do
    it 'renders the sign-in form' do
      get login_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Sign in')
    end
  end

  describe 'POST /login' do
    context 'with valid credentials' do
      it 'signs me in and redirects to the root path' do
        post login_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!' } }

        expect(response).to redirect_to(root_path)
        expect(session[:user_id]).to eq(user.id)
      end

      it 'signs me in when email has different casing (stored downcased at sign-up' do
        post login_path, params: { identity_user: { email: 'ADA@Example.COM', password: 'S3cretPass!' } }

        expect(session[:user_id]).to eq(user.id)
      end
    end

    context 'with invalid credentials' do
      it 'does not sign me in and re-renders the form' do
        post login_path, params: { identity_user: { email: 'ada@example.com', password: 'wrong-password' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(session[:user_id]).to be_nil
      end
    end
  end
end
