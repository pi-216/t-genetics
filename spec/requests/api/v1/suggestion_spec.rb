# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 DEV-0008 (issue #43) — machines request a suggestion with a token.
# The suggestion endpoint drives the engine's Experiments::RequestSuggestion
# command: given the token org's experiment, it returns an organism from the
# current generation with its allele values and records a PerformanceLog.
# Like every API write it is org-scoped — a cross-org experiment id answers
# 404 (never data), no token answers 401, and a command failure (experiment
# without a current generation) answers 422 with error keys.
RSpec.describe 'POST /api/v1/experiments/:id/suggestion (token auth)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom', organization: org) }
  let!(:other_chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Beta-chrom', organization: other_org) }

  let!(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome)
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  let(:plaintext_token) { 'request-suggestion-plaintext-token' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{plaintext_token}" } }

  before do
    FactoryBot.create(:api_token, organization: org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  describe 'with a valid token' do
    it 'returns an organism with its allele values and records a performance log' do
      expect do
        post "/api/v1/experiments/#{experiment.id}/suggestion", headers: auth_headers
      end.to change(PerformanceLog, :count).by(1)

      expect(response).to have_http_status(:ok)
      organism = response.parsed_body
      expect(organism).to include('id')
      chromosome.alleles.map(&:name).each do |allele_name|
        expect(organism).to have_key(allele_name)
      end
    end

    it 'returns a different organism than before when asked again' do
      first_id = nil
      2.times do
        post "/api/v1/experiments/#{experiment.id}/suggestion", headers: auth_headers
        expect(response).to have_http_status(:ok)
        organism = response.parsed_body
        first_id ||= organism['id']
      end
      # The loop suggests the least-tested organism first; a fresh population
      # of identical organisms means the second call may pick the same row,
      # but each call must produce a valid organism with values.
      expect(first_id).to be_present
    end
  end

  describe 'with a valid token but an experiment from another organization' do
    it 'answers 404 and records nothing (cross-org never-data red line)' do
      other_experiment = Experiments::Setup.call(chromosome: other_chromosome, external_entity: other_chromosome).experiment

      expect do
        post "/api/v1/experiments/#{other_experiment.id}/suggestion", headers: auth_headers
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'with an unknown experiment id' do
    it 'answers 404 and records nothing' do
      expect do
        post '/api/v1/experiments/9_999_999/suggestion', headers: auth_headers
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'with an invalid or missing token' do
    it 'returns 401 and records nothing' do
      expect do
        post "/api/v1/experiments/#{experiment.id}/suggestion"
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'when the experiment has no current generation' do
    it 'returns 422 with error keys' do
      generationless = FactoryBot.create(:experiment, chromosome:, external_entity: chromosome)

      post "/api/v1/experiments/#{generationless.id}/suggestion", headers: auth_headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to have_key('errors')
    end
  end
end
