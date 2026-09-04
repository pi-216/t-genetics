# frozen_string_literal: true

require 'swagger_helper'

# OpenAPI contract for outcome reporting on the token-authenticated machine
# API (PRD-0005 DEV-0009 / issue #44). The machine reports the ONE
# customer-reported fitness number against the PerformanceLog its suggestion
# created; the record is org-scoped through experiment → chromosome, so an
# unknown or cross-org log id answers 404 (never data).
RSpec.describe 'TGenetics token API', openapi_spec: 'v1/swagger.yaml', type: :request do
  path '/api/v1/performance_logs/{id}/outcome' do
    post 'Report a fitness outcome (token auth)' do
      tags 'Performance Logs'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Reports the single fitness number a customer measured for the suggested
        organism (the PerformanceLog the suggestion request created). This is
        the only fitness-bearing input in the product — we never evaluate
        anyone's fitness function.

        Authenticate with an org-scoped API token
        (`Authorization: Bearer PLAINTEXT`). A missing, invalid, or revoked
        token receives 401; a log outside the token's organization answers 404;
        a missing or non-numeric `fitness_input_value` answers 422 with error
        keys. Reporting again overwrites the previously recorded value.
      MD

      parameter name: :id, in: :path, type: :integer
      parameter name: :performance_log, in: :body, schema: {
        type: :object,
        required: [:performance_log],
        properties: {
          performance_log: {
            type: :object,
            required: [:fitness_input_value],
            properties: {
              fitness_input_value: { type: :number, description: 'The customer-reported fitness number (e.g. 0.81)' }
            }
          }
        }
      }

      response '200', 'outcome recorded' do
        schema '$ref' => '#/components/schemas/PerformanceLog'

        let(:oapi_org) { FactoryBot.create(:organization, name: 'Loop Labs') }
        let(:oapi_chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: oapi_org) }
        let(:oapi_experiment) { Experiments::Setup.call(chromosome: oapi_chromosome, external_entity: oapi_chromosome).experiment }
        let(:oapi_log) { Experiments::RequestSuggestion.call(experiment: oapi_experiment).performance_log }
        let(:oapi_plaintext) { 'oapi-outcome-plaintext-token' }

        before do
          FactoryBot.create(:api_token, organization: oapi_org, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(oapi_plaintext))
        end

        let(:id) { oapi_log.id }
        let(:Authorization) { "Bearer #{oapi_plaintext}" } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
        let(:performance_log) { { performance_log: { fitness_input_value: 0.81 } } }

        run_test!
      end

      response '404', 'performance log not found (or outside the token org)' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:Authorization) do # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
          organization = FactoryBot.create(:organization, name: 'Loop Labs')
          plaintext = 'oapi-outcome-plaintext-token'
          FactoryBot.create(:api_token, organization: organization, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(plaintext))
          "Bearer #{plaintext}"
        end
        let(:id) { 0 }
        let(:performance_log) { { performance_log: { fitness_input_value: 0.81 } } }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Errors'

        # rswag requires the security-declared header on every example; a nil
        # value sends no Authorization header, exercising the 401 path.
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
        let(:id) { 1 }
        let(:performance_log) { { performance_log: { fitness_input_value: 0.81 } } }

        run_test!
      end
    end
  end
end
