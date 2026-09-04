# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 DEV-0003 (issue #38) — a valid API token authenticates chromosome
# reads over the machine API. The Bearer token resolves to an organization;
# the index must list ONLY that org's chromosomes (org-scope red line), and a
# request without a valid token must not return data.
RSpec.describe 'GET /api/v1/chromosomes (token auth)', type: :request do
  let!(:alpha_org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:beta_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:alpha_chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: alpha_org) }
  let!(:beta_chromosome) { FactoryBot.create(:chromosome, name: 'Beta-chrom', organization: beta_org) }

  let(:plaintext_token) { 'alpha-plaintext-token-123' }

  before do
    FactoryBot.create(:api_token, organization: alpha_org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  def auth_headers(token)
    { 'Authorization' => "Bearer #{token}" }
  end

  describe 'with a valid token' do
    it 'returns 200 and lists the token org\'s chromosomes' do
      get '/api/v1/chromosomes', headers: auth_headers(plaintext_token)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to be_an(Array)
      expect(response.parsed_body).to include(include('name' => alpha_chromosome.name))
    end

    it 'never leaks another organization\'s chromosomes' do
      get '/api/v1/chromosomes', headers: auth_headers(plaintext_token)

      expect(response.parsed_body).not_to include(include('name' => beta_chromosome.name))
    end

    it 'records token usage on last_used_at' do
      token = Identity::ApiToken.find_by!(organization: alpha_org)

      get '/api/v1/chromosomes', headers: auth_headers(plaintext_token)

      expect(token.reload.last_used_at).to be_present
    end
  end

  describe 'without a valid token' do
    it 'returns 401 for a missing Bearer token' do
      get '/api/v1/chromosomes'

      expect(response).to have_http_status(:unauthorized)
      expect(response.body).not_to include('Alpha-chrom')
    end

    it 'returns 401 for an unknown token' do
      get '/api/v1/chromosomes', headers: auth_headers('not-a-real-token')

      expect(response).to have_http_status(:unauthorized)
    end

    it 'returns 401 for a revoked token' do
      Identity::ApiToken.find_by!(organization: alpha_org).update!(revoked_at: Time.current)

      get '/api/v1/chromosomes', headers: auth_headers(plaintext_token)

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
