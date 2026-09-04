# frozen_string_literal: true

require 'swagger_helper'

# OpenAPI contract for the token-authenticated machine API (PRD-0005
# DEV-0003 / issue #38). The /api/v1 surface authenticates with an org-scoped
# Bearer token; the response lists only the token organization's chromosomes.
RSpec.describe 'TGenetics token API', openapi_spec: 'v1/swagger.yaml', type: :request do
  path '/api/v1/chromosomes' do
    get 'List chromosomes (token auth)' do
      tags 'Chromosomes'
      security [{ bearerAuth: [] }]
      produces 'application/json'
      description <<~MD
        Lists the chromosomes of the token's organization.

        Authenticate with an org-scoped API token. Send
        `Authorization: Bearer PLAINTEXT` where PLAINTEXT is the token value
        shown once at creation. A missing, invalid, or revoked token receives
        401; chromosomes of other organizations are never visible.
      MD

      response '200', 'chromosomes listed' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Chromosome' }

        let(:Authorization) do # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive
          organization = FactoryBot.create(:organization, name: 'Loop Labs')
          FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: organization)
          plaintext = 'oapi-known-plaintext-token'
          FactoryBot.create(:api_token, organization: organization, name: 'ci-runner',
                                        token_digest: Identity::ApiToken.digest(plaintext))
          "Bearer #{plaintext}"
        end

        run_test!
      end

      response '401', 'unauthorized' do
        schema '$ref' => '#/components/schemas/Errors'

        # rswag requires the security-declared header on every example; a nil
        # value sends no Authorization header, exercising the 401 path.
        let(:Authorization) { nil } # rubocop:disable RSpec/VariableName -- rswag header let, case-sensitive

        run_test!
      end
    end
  end
end
