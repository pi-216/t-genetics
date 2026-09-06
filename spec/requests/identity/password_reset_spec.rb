# frozen_string_literal: true

require 'rails_helper'

# Devise :recoverable password-reset flow (issue #118). Dev delivery only —
# the test environment uses ActionMailer :test, matching the no-external-mail
# red line. The behavior pinned here: a forgotten password can be reset via
# the emailed link, and account existence is never disclosed.
#
# Devise stores only a token DIGEST in the DB — the email carries the raw
# one-time token, so specs parse it out of the delivered mail body (never
# from the users table).
RSpec.describe 'Password reset', type: :request do
  let!(:user) { FactoryBot.create(:user, email: 'ada@example.com', password: 'S3cretPass!') }

  # Sends reset instructions and returns the RAW token from the email link.
  def raw_reset_token
    expect { user.send_reset_password_instructions }.to change(ActionMailer::Base.deliveries, :count).by(1)
    mail = ActionMailer::Base.deliveries.last
    mail.body.encoded[/reset_password_token=([^&\s"']+)/, 1]
  end

  describe 'GET /password/new' do
    it 'renders the reset-request form' do
      get new_user_password_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('password')
    end
  end

  describe 'POST /password' do
    it 'emails reset instructions to an existing email and redirects to login' do
      expect do
        post user_password_path, params: { user: { email: 'ada@example.com' } }
      end.to change(ActionMailer::Base.deliveries, :count).by(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to eq(['ada@example.com'])
      expect(mail.subject).to match(/reset/i)

      # A one-time token was generated (digest at rest) and the mail carries a
      # reset link with the raw token.
      user.reload
      expect(user.reset_password_token).to be_present
      expect(mail.body.encoded).to include('reset_password_token=')

      expect(response).to redirect_to(login_path)
    end

    it 'does not disclose account existence for an unknown email' do
      expect do
        post user_password_path, params: { user: { email: 'nobody@example.com' } }
      end.not_to change(ActionMailer::Base.deliveries, :count)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'password reset completion' do
    let(:reset_token) { raw_reset_token }

    it 'renders the edit form with a valid token' do
      get edit_user_password_path, params: { reset_password_token: reset_token }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('New password')
    end

    it 'updates the password and invalidates the old one' do
      patch user_password_path, params: reset_params(reset_token)

      user.reload
      expect(user.valid_password?('N3w-S3cretPass!')).to be true
      expect(user.valid_password?('S3cretPass!')).to be false
      expect(user.reset_password_token).to be_nil
    end
  end

  def reset_params(token)
    { user: { reset_password_token: token,
              password: 'N3w-S3cretPass!',
              password_confirmation: 'N3w-S3cretPass!' } }
  end
end
