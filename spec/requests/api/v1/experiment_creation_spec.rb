# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 DEV-0007 (issue #42) — machines create experiments with a token.
# The write is org-scoped like every API call: the experiment always targets a
# chromosome in the token's organization (the client can never choose the
# organization, and a cross-org chromosome id answers 404 — never data). The
# new experiment runs the engine's Experiments::Setup command, so it carries a
# current generation and initial population. No token -> 401 and no row.
RSpec.describe 'POST /api/v1/experiments (token auth)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: org) }
  let!(:other_chromosome) { FactoryBot.create(:chromosome, name: 'Beta-chrom', organization: other_org) }

  let(:plaintext_token) { 'create-experiment-plaintext-token' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{plaintext_token}" } }

  before do
    FactoryBot.create(:api_token, organization: org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  describe 'with a valid token' do
    it 'creates an experiment (with a current generation) in the token org and returns 201' do
      expect do
        post '/api/v1/experiments', params: { experiment: { chromosome_id: chromosome.id } }, headers: auth_headers
      end.to change(Experiment, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to include('chromosome_id' => chromosome.id)
      expect(Experiment.order(:id).last.current_generation).to be_present
      expect(Experiment.order(:id).last.current_generation.organisms.count).to be_positive
    end

    it 'makes the new experiment appear in the authenticated list' do
      post '/api/v1/experiments', params: { experiment: { chromosome_id: chromosome.id } }, headers: auth_headers

      get '/api/v1/experiments', headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include(include('chromosome_id' => chromosome.id))
    end

    it 'refuses a chromosome from another organization (cross-org 404, never data)' do
      expect do
        post '/api/v1/experiments', params: { experiment: { chromosome_id: other_chromosome.id } }, headers: auth_headers
      end.not_to change(Experiment, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'keeps the new experiment invisible to another organization token' do
      post '/api/v1/experiments', params: { experiment: { chromosome_id: chromosome.id } }, headers: auth_headers

      other_token = 'other-org-plaintext-token'
      FactoryBot.create(:api_token, organization: other_org,
                                    name: 'ci-runner',
                                    token_digest: Identity::ApiToken.digest(other_token))

      get '/api/v1/experiments', headers: { 'Authorization' => "Bearer #{other_token}" }

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.filter_map { |e| e['chromosome_id'] }).not_to include(chromosome.id)
    end
  end

  describe 'with an invalid or missing token' do
    it 'returns 401 and creates nothing' do
      expect do
        post '/api/v1/experiments', params: { experiment: { chromosome_id: chromosome.id } }
      end.not_to change(Experiment, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'with an unknown chromosome id' do
    it 'returns 404 and creates nothing' do
      expect do
        post '/api/v1/experiments', params: { experiment: { chromosome_id: 9_999_999 } }, headers: auth_headers
      end.not_to change(Experiment, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
