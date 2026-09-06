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
      it 'signs me in and redirects to the experiments workspace' do
        post login_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!' } }

        expect(response).to redirect_to(experiments_path)
        expect(signed_in_user).to eq(user)
      end

      it 'signs me in when email has different casing (stored downcased at sign-up' do
        post login_path, params: { identity_user: { email: 'ADA@Example.COM', password: 'S3cretPass!' } }

        expect(signed_in_user).to eq(user)
      end
    end

    context 'with invalid credentials' do
      it 'does not sign me in and re-renders the form' do
        post login_path, params: { identity_user: { email: 'ada@example.com', password: 'wrong-password' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(signed_in_user).to be_nil
      end
    end
  end

  describe 'POST /logout' do
    context 'when signed in' do
      it 'signs me out and redirects to the login page' do
        post login_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!' } }
        expect(signed_in_user).to eq(user)

        post logout_path

        expect(signed_in_user).to be_nil
        expect(response).to redirect_to(login_path)
      end
    end
  end

  # Issue #118: the session is now owned by Devise/Warden. The hand-rolled
  # session[:user_id] key is gone — a successful sign-in must leave it nil
  # while the warden session carries the user.
  describe 'session mechanism (issue #118)' do
    it 'establishes a warden session and stops writing session[:user_id]' do
      post login_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!' } }

      expect(signed_in_user).to eq(user)
      expect(session[:user_id]).to be_nil
    end
  end

  # Issue #118 regression fix: Devise's stock SessionsController guard
  # (require_no_authentication) redirects an already-signed-in user away from
  # POST /login, so the second pair of credentials is never processed. The
  # pre-Devise flow replaced session[:user_id] unconditionally, and account
  # switching via POST /login is part of the wire contract — the cross-org
  # organisms spec exercises exactly this to switch organizations mid-example
  # (organisms_spec.rb:82 was answering 200 instead of 404 on this).
  describe 're-authentication while already signed in (issue #118)' do
    it 'switches the warden session to the newly posted credentials' do
      post login_path, params: { identity_user: { email: 'ada@example.com', password: 'S3cretPass!' } }
      expect(signed_in_user).to eq(user)

      other = FactoryBot.create(:user, email: 'bob@example.com', password: 'OtherPass!9')
      post login_path, params: { identity_user: { email: 'bob@example.com', password: 'OtherPass!9' } }

      expect(signed_in_user).to eq(other)
    end
  end
end
