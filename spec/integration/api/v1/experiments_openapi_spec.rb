# frozen_string_literal: true

require 'swagger_helper'

# OpenAPI contract for the token-authenticated suggestion request (PRD-0005
# DEV-0008 / issue #43). A machine asks the token org's experiment for the
# next organism to test; the engine's RequestSuggestion command picks the
# least-tested organism of the current generation, records a PerformanceLog
# for that suggestion, and the response carries the organism's allele values.
# The experiment is resolved org-scoped through its chromosome, so an unknown
# or cross-org id answers 404 (never data).
RSpec.describe 'TGenetics token API', openapi_spec: 'v1/swagger.yaml', type: :request do
  path '/api/v1/experiments/{id}/suggestion' do
    post 'Request a suggestion (token auth)' do
      tags 'Experiments'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Requests the next organism to test from the token organization's
        experiment. The engine suggests the least-tested organism of the
        current generation and records the suggestion as a PerformanceLog; the
        customer then tests the organism on their own infrastructure and
        reports the single fitness number via the outcome endpoint.

        Authenticate with an org-scoped API token
        (`Authorization: Bearer <token>`). A missing, invalid, or revoked
        token receives 401; an experiment outside the token's organization —
        or an unknown id — answers 404 with error keys; an experiment without
        a current generation answers 422 with error keys.
      MD

      parameter name: :id, in: :path, type: :integer
      parameter name: :Authorization, in: :header, type: :string,
                description: 'Bearer token (org-scoped machine API token)'

      response '200', 'suggestion returned (organism with values)' do
        schema '$ref' => '#/components/schemas/Organism'

        let(:oapi_org) { FactoryBot.create(:organization, name: 'Loop Labs') }
        let(:oapi_chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: oapi_org) }
        let(:oapi_experiment) { Experiments::Setup.call(chromosome: oapi_chromosome, external_entity: oapi_chromosome).experiment }
        let(:oapi_plaintext) { 'oapi-suggestion-plaintext-token' }

        before do
          FactoryBot.create(:api_token, organization: oapi_org, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(oapi_plaintext))
        end

        let(:id) { oapi_experiment.id }
        let(:Authorization) { "Bearer #{oapi_plaintext}" } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive

        run_test!
      end

      response '404', 'experiment not found (or outside the token org)' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:Authorization) do # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
          organization = FactoryBot.create(:organization, name: 'Loop Labs')
          plaintext = 'oapi-suggestion-plaintext-token'
          FactoryBot.create(:api_token, organization: organization, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(plaintext))
          "Bearer #{plaintext}"
        end
        let(:id) { 0 }

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Errors'

        # rswag requires the security-declared header on every example; a nil
        # value sends no Authorization header, exercising the 401 path.
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
        let(:id) { 1 }

        run_test!
      end

      response '422', 'experiment has no current generation' do
        schema '$ref' => '#/components/schemas/Errors'

        let!(:oapi_org) { FactoryBot.create(:organization, name: 'Loop Labs') }
        let(:Authorization) do # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
          plaintext = 'oapi-suggestion-plaintext-token'
          FactoryBot.create(:api_token, organization: oapi_org, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(plaintext))
          "Bearer #{plaintext}"
        end
        # A bare experiment without a Setup-minted current generation: the
        # suggestion command fails and the endpoint answers 422 with errors.
        let(:id) do
          chromosome = FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: oapi_org)
          FactoryBot.create(:experiment, chromosome: chromosome, external_entity: chromosome).id
        end

        run_test!
      end
    end
  end
end
