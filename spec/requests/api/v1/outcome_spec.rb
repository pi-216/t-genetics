# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 DEV-0009 (issue #44) -- machines report a fitness outcome with a
# token. The outcome endpoint targets the PerformanceLog that a suggestion
# created (the "suggestion" the machine is reporting on) and drives the
# engine's Experiments::RecordOutcome command -- the ONLY fitness-bearing input
# in the product is this customer-reported number (never our eval). Like every
# API write it is org-scoped: a performance log outside the token's
# organization answers 404 (never data), no token answers 401, and a missing
# or non-numeric fitness value answers 422 with error keys.
RSpec.describe 'POST /api/v1/performance_logs/:id/outcome (token auth)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: org) }
  let!(:other_chromosome) { FactoryBot.create(:chromosome, name: 'Beta-chrom', organization: other_org) }

  let!(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome)
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  let!(:performance_log) do
    suggestion_result = Experiments::RequestSuggestion.call(experiment: experiment)
    raise "Suggestion failed: #{suggestion_result.errors.inspect}" unless suggestion_result.success?

    suggestion_result.performance_log
  end

  let(:plaintext_token) { 'report-outcome-plaintext-token' }
  let(:auth_headers) { { 'Authorization' => "Bearer #{plaintext_token}" } }
  let(:json_headers) { { 'Content-Type' => 'application/json' } }

  before do
    FactoryBot.create(:api_token, organization: org,
                                  name: 'ci-runner',
                                  token_digest: Identity::ApiToken.digest(plaintext_token))
  end

  def post_outcome(log: performance_log, payload: { fitness_input_value: 0.81 }, headers: auth_headers)
    post "/api/v1/performance_logs/#{log.id}/outcome",
         params: { performance_log: payload }.to_json,
         headers: headers.merge(json_headers)
  end

  describe 'with a valid token' do
    it 'records the reported fitness outcome on the performance log and returns 200' do
      post_outcome

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to include('fitness_input_value' => 0.81)
      expect(response.parsed_body).to include('id' => performance_log.id)
      expect(response.parsed_body).to include('experiment_id' => experiment.id)
      expect(response.parsed_body).to include('organism_id' => performance_log.organism_id)

      expect_outcome_recorded(performance_log, 0.81)
    end

    it 'accepts a numeric fitness string ("0.81")and stores the float' do
      post_outcome(payload: { fitness_input_value: '0.81' })

      expect(response).to have_http_status(:ok)
      expect(performance_log.reload.fitness_input_value).to eq(0.81)
    end

    it 'allows a later report to overwrite the outcome value' do
      post_outcome(payload: { fitness_input_value: 0.5 })
      expect(response).to have_http_status(:ok)

      post_outcome(payload: { fitness_input_value: 0.81 })
      expect(response).to have_http_status(:ok)

      expect(performance_log.reload.fitness_input_value).to eq(0.81)
    end
  end

  describe 'with a performance log from another organization' do
    it 'answers 404and never leaks or mutates the other org log' do
      other_log = other_org_suggestion(other_org_experiment)

      post_outcome(log: other_log, payload: { fitness_input_value: 0.5 })

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['errors']).to be_present
      expect(other_log.reload.fitness_input_value).to be_nil
      expect(other_log.outcome_recorded_at).to be_nil
    end
  end

  describe 'with an unknown performance log id' do
    it 'answers 404' do
      post '/api/v1/performance_logs/999999999/outcome',
           params: { performance_log: { fitness_input_value: 0.81 } }.to_json,
           headers: auth_headers.merge(json_headers)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body['errors']).to be_present
    end
  end

  describe 'without or with an invalid token' do
    it 'answers 401and records nothing' do
      expect do
        post "/api/v1/performance_logs/#{performance_log.id}/outcome",
             params: { performance_log: { fitness_input_value: 0.81 } }.to_json,
             headers: json_headers
      end.not_to(change { performance_log.reload.outcome_recorded_at })

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'with a malformed payload' do
    it 'answers 422 with error keys when fitness is missing' do
      post "/api/v1/performance_logs/#{performance_log.id}/outcome",
           params: { performance_log: {} }.to_json,
           headers: auth_headers.merge(json_headers)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to be_present
      expect(performance_log.reload.fitness_input_value).to be_nil
    end

    it 'answers 422 with error keys when fitness is not a number' do
      post "/api/v1/performance_logs/#{performance_log.id}/outcome",
           params: { performance_log: { fitness_input_value: 'not-a-number' } }.to_json,
           headers: auth_headers.merge(json_headers)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body['errors']).to include('fitness_input_value' => ['must be a number'])
      expect(performance_log.reload.fitness_input_value).to be_nil
    end
  end

  private

  def expect_outcome_recorded(log, fitness)
    log.reload
    expect(log.fitness_input_value).to eq(fitness)
    expect(log.outcome_recorded_at).to be_present
    expect(log.suggested_at).to be_present
  end

  def other_org_experiment
    result = Experiments::Setup.call(chromosome: other_chromosome, external_entity: other_chromosome)
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  def other_org_suggestion(other_experiment)
    result = Experiments::RequestSuggestion.call(experiment: other_experiment)
    raise "Suggestion failed: #{result.errors.inspect}" unless result.success?

    result.performance_log
  end
end
