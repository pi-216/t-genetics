# frozen_string_literal: true

require 'swagger_helper'

# OpenAPI contract for the token-authenticated suggestion request (PRD-0005
# DEV-0008 / issue #43). A machine asks the token org's experiment for the
# next organism to test; the engine's RequestSuggestion command draws
# uniformly at random among the current generation's untested organisms (no
# reported fitness — founder ruling 2026-09-04, issue #130), records a
# PerformanceLog for that suggestion, and the response carries the organism's
# allele values.
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
        experiment. The engine draws uniformly at random among the current
        generation's untested organisms (those without a reported fitness — a
        PerformanceLog with a fitness_input_value) and records the suggestion
        as a PerformanceLog; a reported organism is never suggested again
        while the generation is current. The customer then tests the organism
        on their own infrastructure and reports the single fitness number via
        the outcome endpoint.

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

  path '/api/v1/experiments/{id}/current_suggestion' do
    get 'Read the current pending suggestion (token auth)' do
      tags 'Experiments'
      security [{ bearerAuth: [] }]
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Reads the token organization's experiment current PENDING suggestion
        — the most recent suggested organism that has NOT yet had its outcome
        reported (no PerformanceLog with a fitness_input_value). This is the
        long-lived-suggestion read (PRD-0005 Q4): a suggestion is shown to
        the customer and their outcome may be reported days or weeks later
        (canonical case: tip-amount suggestions on a payment form), so a
        machine re-presenting the SAME suggestion across sessions needs a
        read that does NOT draw a new random organism. Unlike
        POST /suggestion, this endpoint never creates a PerformanceLog.

        The suggestion stays stable across re-reads until an outcome is
        recorded (the pending log gains a fitness value) or the generation
        evolves (the organism's generation is no longer current). When
        nothing is pending, the response is an explicit
        `{"performance_log": null, "organism": null}` — never silent.

        Authenticate with an org-scoped API token
        (`Authorization: Bearer <token>`). A missing, invalid, or revoked
        token receives 401; an experiment outside the token's organization —
        or an unknown id — answers 404 with error keys.
      MD

      parameter name: :id, in: :path, type: :integer
      parameter name: :Authorization, in: :header, type: :string,
                description: 'Bearer token (org-scoped machine API token)'

      response '200', 'current pending suggestion (or explicit empty)' do
        schema type: :object,
               properties: {
                 performance_log: { '$ref' => '#/components/schemas/PerformanceLog', nullable: true },
                 organism: { '$ref' => '#/components/schemas/Organism', nullable: true }
               }

        let(:oapi_org) { FactoryBot.create(:organization, name: 'Loop Labs') }
        let(:oapi_chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: oapi_org) }
        let(:oapi_experiment) { Experiments::Setup.call(chromosome: oapi_chromosome, external_entity: oapi_chromosome).experiment }
        let(:oapi_plaintext) { 'oapi-current-suggestion-plaintext-token' }

        before do
          FactoryBot.create(:api_token, organization: oapi_org, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(oapi_plaintext))
          # A pending suggestion must exist for the happy-path example (the
          # pending log carries no fitness value).
          result = Experiments::RequestSuggestion.call(experiment: oapi_experiment)
          raise "RequestSuggestion failed: #{result.errors.inspect}" unless result.success?
        end

        let(:id) { oapi_experiment.id }
        let(:Authorization) { "Bearer #{oapi_plaintext}" } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive

        run_test!
      end

      response '404', 'experiment not found (or outside the token org)' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:Authorization) do # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
          organization = FactoryBot.create(:organization, name: 'Loop Labs')
          plaintext = 'oapi-current-suggestion-plaintext-token'
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
    end
  end
end
