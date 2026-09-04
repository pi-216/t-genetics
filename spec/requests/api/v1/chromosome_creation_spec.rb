# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 DEV-0006 (issue #41) — machines create chromosomes with a token.
# The write is org-scoped like every API read: the new chromosome always
# belongs to the token's organization (never settable by the client), appears
# in the token org's list, and is invisible to other orgs. No token → 401 and
# no row. Malformed (blank-name) payloads answer 422 with error keys, the same
# contract the legacy rswag POST /chromosomes spec already documents.
RSpec.describe 'POST /api/v1/chromosomes (token auth)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let(:plaintext_token) { 'create-chromosome-plaintext-token' }

  let(:auth_headers) { { 'Authorization' => "Bearer #{plaintext_token}" } }

  before do
    FactoryBot.create(:api_token, organization: org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  describe 'with a valid token' do
    it 'creates a chromosome in the token organization and returns 201' do
      expect do
        post '/api/v1/chromosomes', params: { chromosome: { name: 'Gamma-chrom' } }, headers: auth_headers
      end.to change(Chromosome, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('name' => 'Gamma-chrom')
      expect(Chromosome.order(:id).last.organization).to eq(org)
    end

    it 'makes the new chromosome appear in the authenticated list' do
      post '/api/v1/chromosomes', params: { chromosome: { name: 'Gamma-chrom' } }, headers: auth_headers

      get '/api/v1/chromosomes', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(include('name' => 'Gamma-chrom'))
    end

    it 'never lets the client choose another organization via the payload' do
      post '/api/v1/chromosomes',
           params: { chromosome: { name: 'Rogue-chrom', organization_id: other_org.id } },
           headers: auth_headers

      expect(Chromosome.find_by(name: 'Rogue-chrom').organization).to eq(org)
    end

    it 'keeps the new chromosome invisible to another organization token' do
      post '/api/v1/chromosomes', params: { chromosome: { name: 'Gamma-chrom' } }, headers: auth_headers

      other_token = 'other-org-plaintext-token'
      FactoryBot.create(:api_token, organization: other_org,
                                    name: 'ci-runner',
                                    token_digest: Identity::ApiToken.digest(other_token))

      get '/api/v1/chromosomes', headers: { 'Authorization' => "Bearer #{other_token}" }

      expect(response.parsed_body).not_to include(include('name' => 'Gamma-chrom'))
    end
  end

  describe 'with an invalid or missing token' do
    it 'returns 401 and creates nothing' do
      expect do
        post '/api/v1/chromosomes', params: { chromosome: { name: 'Ghost-chrom' } }
      end.not_to change(Chromosome, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'with a malformed payload' do
    it 'returns 422 with error keys and creates nothing' do
      expect do
        post '/api/v1/chromosomes', params: { chromosome: { name: '' } }, headers: auth_headers
      end.not_to change(Chromosome, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body).to have_key('errors')
    end
  end
end
