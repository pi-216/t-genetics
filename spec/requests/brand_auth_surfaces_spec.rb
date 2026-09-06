# frozen_string_literal: true

require 'rails_helper'

# PRD-0006 (issue #112, apply-pass) — the auth surfaces (sign-in, sign-up,
# password reset) are reachable without a session and were the last
# unreformed scaffold holders of the stock teal form treatment. This request
# spec is the non-JS regression net: the rendered page carries zero stock
# palette tokens, the form fields wear the brand line/surface/ink treatment,
# and the primary submit uses the locked button-primary spec.
AUTH_FORBIDDEN_PALETTE = /teal|indigo|coral|ochre|olive/

# -- no class under test.
RSpec.describe 'Brand tokens on auth surfaces', type: :request do
  shared_examples 'a brand-themed auth page' do
    it 'renders without any stock palette classes' do
      get path

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to match(AUTH_FORBIDDEN_PALETTE)
    end

    it 'renders form fields with the brand line/surface/ink treatment' do
      get path

      expect(response.body).to include('border border-line bg-surface px-3 py-2 text-ink')
    end

    it 'renders the primary submit with the button-primary token utilities' do
      get path

      expect(response.body).to include('bg-signal')
      expect(response.body).to include('text-onSignal')
    end
  end

  context 'with the sign-in page' do
    let(:path) { login_path }

    it_behaves_like 'a brand-themed auth page'
  end

  context 'with the sign-up page' do
    let(:path) { register_path }

    it_behaves_like 'a brand-themed auth page'
  end

  context 'with the password reset page' do
    let(:path) { new_user_password_path }

    it_behaves_like 'a brand-themed auth page'
  end
end
