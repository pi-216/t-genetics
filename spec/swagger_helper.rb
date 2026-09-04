# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'TGenetics API',
        version: 'v1'
      },
      paths: {},
      components: {
        securitySchemes: {
          bearerAuth: {
            type: :http,
            scheme: :bearer,
            bearerFormat: 'string'
          }
        },
        schemas: {
          Chromosome: {
            type: :object,
            required: %i[id name alleles],
            properties: {
              id: { type: :integer },
              name: { type: :string },
              alleles: { type: :array, items: { '$ref' => '#/components/schemas/Allele' } }
            }
          },
          Allele: {
            type: :object,
            required: %i[id chromosome_id name type],
            properties: {
              id: { type: :integer },
              chromosome_id: { type: :integer },
              name: { type: :string },
              type: { type: :string },
              minimum: { type: :number, nullable: true },
              maximum: { type: :number, nullable: true },
              choices: { type: :array, items: { type: :string }, nullable: true }
            }
          },
          Generation: {
            type: :object,
            required: %i[id chromosome_id],
            properties: {
              id: { type: :integer },
              chromosome_id: { type: :integer }
            }
          },
          Organism: {
            type: :object,
            additionalProperties: {
              oneOf: [
                { type: :string },
                { type: :number },
                { type: :boolean },
                { type: :null }
              ]
            }
          },
          Errors: {
            type: :object,
            properties: {
              errors: {
                oneOf: [
                  { type: :array, items: { type: :string } },
                  { type: :object }
                ]
              }
            }
          }
        }
      },
      servers: [
        {
          url: 'http://{defaultHost}',
          variables: {
            defaultHost: {
              default: 'localhost:3001'
            }
          }
        }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end
