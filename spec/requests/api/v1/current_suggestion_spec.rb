# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 Q4 (issue #131) — the token API's "current suggestion" READ. A
# suggestion is a long-lived object (suggested → shown → outcome) and the gap
# between "shown a suggestion" and "they report the outcome" can be days or
# weeks (canonical case: tip-amount suggestions on a payment form). The
# POST /suggestion endpoint draws a NEW random organism each call, so a
# machine re-presenting the same suggestion across sessions needs a read that
# returns the current PENDING suggestion WITHOUT creating a new PerformanceLog.
#
# Contract (mirrors every other token endpoint):
#   - org-scoped: a cross-org or unknown experiment id answers 404 (never data)
#   - token auth: a missing/invalid/revoked token answers 401
#   - when a suggestion is pending, 200 with { performance_log, organism }
#   - when nothing is pending, 200 with explicit { performance_log: null,
#     organism: null } — never silent, 404 stays reserved for not-found/cross-org
#   - a re-read is STABLE: same organism until an outcome is recorded or the
#     generation evolves
RSpec.describe 'GET /api/v1/experiments/:id/current_suggestion (token auth)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom', organization: org) }
  let!(:other_chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Beta-chrom', organization: other_org) }

  let!(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome)
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  let(:plaintext_token) { 'current-suggestion-plaintext-token' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{plaintext_token}" } }
  let(:path) { "/api/v1/experiments/#{experiment.id}/current_suggestion" }

  before do
    FactoryBot.create(:api_token, organization: org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  # Requests a suggestion through the real command (creates a pending
  # PerformanceLog — no fitness value yet) and returns the suggested organism.
  def request_suggestion
    result = Experiments::RequestSuggestion.call(experiment:)
    raise "RequestSuggestion failed: #{result.errors.inspect}" unless result.success?

    result.organism
  end

  describe 'when a suggestion is pending' do
    let!(:suggested_organism) { request_suggestion }

    it 'returns the pending suggestion and does NOT create a new PerformanceLog' do
      logs_before = PerformanceLog.count

      get path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(PerformanceLog.count).to eq(logs_before)

      body = response.parsed_body
      expect(body['organism']['id']).to eq(suggested_organism.id)
      chromosome.alleles.map(&:name).each do |allele_name|
        expect(body['organism']).to have_key(allele_name)
      end
      expect(body['performance_log']['id']).to eq(PerformanceLog.where(experiment_id: experiment.id).first.id)
    end

    it 'is stable across re-reads (same organism every time)' do
      3.times do
        get path, headers: auth_headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['organism']['id']).to eq(suggested_organism.id)
      end
    end
  end

  describe 'once an outcome is recorded against the pending suggestion' do
    before do
      suggested = request_suggestion
      log = PerformanceLog.where(experiment_id: experiment.id, organism_id: suggested.id).first
      outcome = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end

    it 'returns the explicit empty state (no fitness-carrying suggestion pending)' do
      get path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('performance_log' => nil, 'organism' => nil)
    end
  end

  describe 'when nothing has ever been suggested' do
    it 'returns the explicit empty state' do
      get path, headers: auth_headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq('performance_log' => nil, 'organism' => nil)
    end
  end

  describe 'with a valid token but an experiment from another organization' do
    it 'answers 404 (cross-org never-data red line)' do
      other_experiment = Experiments::Setup.call(chromosome: other_chromosome, external_entity: other_chromosome).experiment

      get "/api/v1/experiments/#{other_experiment.id}/current_suggestion", headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to have_key('errors')
    end
  end

  describe 'with an unknown experiment id' do
    it 'answers 404' do
      get '/api/v1/experiments/9_999_999/current_suggestion', headers: auth_headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body).to have_key('errors')
    end
  end

  describe 'with an invalid or missing token' do
    it 'returns 401' do
      get path

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
