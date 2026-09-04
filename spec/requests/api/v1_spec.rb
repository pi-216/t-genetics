# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'TGenetics API', openapi_spec: 'v1/swagger.yaml', type: :request do
  # Finding #56 (founder ruling 2026-09-04): the workspace JSON surface these
  # paths document requires sign-in. Every example authenticates a session and
  # creates org-scoped chromosomes — anonymous access is the vulnerability this
  # spec used to encode.
  let(:org) { FactoryBot.create(:organization) }

  before do
    sign_in_as(organization: org)
    Chromosome.create!(name: 'experiment 1', organization: org)
  end

  path '/chromosomes' do
    get 'List chromosomes' do
      tags 'Chromosomes'
      produces 'application/json'
      description <<~MD
        Lists chromosomes (the top-level "genome template").

        A chromosome contains alleles (parameters) and generations (population snapshots).
        Typical workflow: create chromosome → add alleles → create first generation → update fitness → procreate.
      MD

      response '200', 'chromosomes listed' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Chromosome' }

        run_test!
      end
    end

    post 'Create chromosome' do
      tags 'Chromosomes'
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Creates a new chromosome container.

        After creating the chromosome, you typically create alleles under it and then bootstrap the first generation.
      MD
      parameter name: :chromosome, in: :body, schema: {
        type: :object,
        required: [:chromosome],
        properties: {
          chromosome: {
            type: :object,
            required: [:name],
            properties: {
              name: { type: :string }
            }
          }
        }
      }

      response '201', 'chromosome created' do
        schema '$ref' => '#/components/schemas/Chromosome'
        let(:chromosome) { { chromosome: { name: 'experiment 1' } } }

        run_test!
      end

      response '422', 'invalid request' do
        schema '$ref' => '#/components/schemas/Errors'
        let(:chromosome) { { chromosome: { name: '' } } }

        run_test!
      end
    end
  end

  path '/chromosomes/{id}' do
    parameter name: :id, in: :path, type: :integer

    get 'Show chromosome' do
      tags 'Chromosomes'
      produces 'application/json'
      description <<~MD
        Fetches a single chromosome, including its allele definitions.

        Use this to discover the parameter space (alleles) before creating organisms and setting fitness.
      MD

      response '200', 'chromosome found' do
        schema '$ref' => '#/components/schemas/Chromosome'
        let(:id) { Chromosome.create!(name: 'experiment 1', organization: org).id }

        run_test!
      end

      response '404', 'not found' do
        let(:id) { 0 }

        run_test!
      end
    end

    patch 'Update chromosome' do
      tags 'Chromosomes'
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Updates chromosome metadata.

        This does not modify existing generations/organisms; it only updates the chromosome record (currently: name).
      MD
      parameter name: :chromosome, in: :body, schema: {
        type: :object,
        required: [:chromosome],
        properties: {
          chromosome: {
            type: :object,
            properties: {
              name: { type: :string }
            }
          }
        }
      }

      response '200', 'chromosome updated' do
        schema '$ref' => '#/components/schemas/Chromosome'
        let(:existing) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:id) { existing.id }
        let(:chromosome) { { chromosome: { name: 'experiment 2' } } }

        run_test!
      end

      response '422', 'invalid request' do
        schema '$ref' => '#/components/schemas/Errors'
        let(:existing) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:id) { existing.id }
        let(:chromosome) { { chromosome: { name: '' } } }

        run_test!
      end
    end

    delete 'Delete chromosome' do
      tags 'Chromosomes'
      produces 'application/json'
      description <<~MD
        Deletes a chromosome and all nested resources (alleles, generations, organisms).

        Use with care: this is a destructive reset of the entire experiment.
      MD

      response '204', 'chromosome deleted' do
        let(:id) { Chromosome.create!(name: 'experiment 1', organization: org).id }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/alleles' do
    parameter name: :chromosome_id, in: :path, type: :integer

    get 'List alleles' do
      tags 'Alleles'
      produces 'application/json'
      description <<~MD
        Lists all alleles for a chromosome.

        Alleles define the "search space" (parameters) that each organism will carry values for.
      MD

      response '200', 'alleles listed' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Allele' }

        let(:chromosome_id) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome.id
        end

        run_test!
      end
    end

    post 'Create allele' do
      tags 'Alleles'
      consumes 'application/json'
      produces 'application/json'
      parameter name: :allele, in: :body, schema: {
        type: :object,
        required: [:allele],
        properties: {
          allele: {
            type: :object,
            required: %i[name type],
            properties: {
              name: { type: :string },
              type: { type: :string, description: 'One of Integer|Float|Boolean|Option' },
              minimum: { type: :number, nullable: true },
              maximum: { type: :number, nullable: true },
              choices: { type: :array, items: { type: :string }, nullable: true }
            }
          }
        }
      }

      description <<~MD
        Creates an allele within the chromosome using a typed request body.

        Supported `type` values:
        - `Integer` (requires `minimum` + `maximum`)
        - `Float` (requires `minimum` + `maximum`)
        - `Boolean` (no additional fields)
        - `Option` (requires `choices`)
      MD

      request_body_example name: 'integer', summary: 'Integer allele', value: {
        allele: { name: 'legs', type: 'Integer', minimum: 1, maximum: 50 }
      }
      request_body_example name: 'float', summary: 'Float allele', value: {
        allele: { name: 'height', type: 'Float', minimum: 1.0, maximum: 10.0 }
      }
      request_body_example name: 'boolean', summary: 'Boolean allele', value: {
        allele: { name: 'flies', type: 'Boolean' }
      }
      request_body_example name: 'option', summary: 'Option allele', value: {
        allele: { name: 'color', type: 'Option', choices: %w[green blue] }
      }

      response '201', 'allele created' do
        schema '$ref' => '#/components/schemas/Allele'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:chromosome_id) { chromosome.id }
        let(:allele) { { allele: { name: 'legs', type: 'Integer', minimum: 1, maximum: 50 } } }

        example 'application/json', :integer, {
          id: 1,
          chromosome_id: 1,
          name: 'legs',
          type: 'Integer',
          minimum: 1,
          maximum: 50
        }

        example 'application/json', :float, {
          id: 2,
          chromosome_id: 1,
          name: 'height',
          type: 'Float',
          minimum: 1.0,
          maximum: 10.0
        }

        example 'application/json', :boolean, {
          id: 3,
          chromosome_id: 1,
          name: 'flies',
          type: 'Boolean'
        }

        example 'application/json', :option, {
          id: 4,
          chromosome_id: 1,
          name: 'color',
          type: 'Option',
          choices: %w[green blue]
        }

        run_test!
      end

      response '422', 'invalid request' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:chromosome_id) { chromosome.id }
        let(:allele) { { allele: { name: 'legs', type: 'Integer' } } }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/alleles/{id}' do
    parameter name: :chromosome_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show allele' do
      tags 'Alleles'
      produces 'application/json'
      description <<~MD
        Fetches a single allele definition within a chromosome.

        Useful for inspecting constraints (e.g., min/max or option choices) before creating/updating organisms.
      MD

      response '200', 'allele found' do
        schema '$ref' => '#/components/schemas/Allele'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:created) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }
        let(:chromosome_id) { chromosome.id }
        let(:id) { created.id }

        run_test!
      end

      response '404', 'not found' do
        let(:chromosome_id) { Chromosome.create!(name: 'experiment 1', organization: org).id }
        let(:id) { 0 }

        run_test!
      end
    end

    patch 'Update allele' do
      tags 'Alleles'
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Updates an existing allele.

        Rules:
        - You may change the allele name and constraints within its current type.
        - You may NOT change the allele type (e.g., Integer → Float).
      MD
      parameter name: :allele, in: :body, schema: {
        type: :object,
        required: [:allele],
        properties: {
          allele: {
            type: :object,
            properties: {
              name: { type: :string },
              type: { type: :string },
              minimum: { type: :number, nullable: true },
              maximum: { type: :number, nullable: true },
              choices: { type: :array, items: { type: :string }, nullable: true }
            }
          }
        }
      }

      response '200', 'allele updated' do
        schema '$ref' => '#/components/schemas/Allele'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:existing) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }
        let(:chromosome_id) { chromosome.id }
        let(:id) { existing.id }
        let(:allele) { { allele: { minimum: 2, maximum: 60 } } }

        after do |example|
          example.metadata[:response][:content] ||= {}
          example.metadata[:response][:content]['application/json'] = { example: JSON.parse(response.body, symbolize_names: true) }
        end

        run_test!
      end

      response '422', 'type cannot be changed' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:existing) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }
        let(:chromosome_id) { chromosome.id }
        let(:id) { existing.id }
        let(:allele) { { allele: { type: 'Float' } } }

        run_test!
      end
    end

    delete 'Delete allele' do
      tags 'Alleles'
      produces 'application/json'
      description <<~MD
        Deletes an allele from a chromosome.

        Note: existing organism values for this allele (in existing generations) may become incomplete.
      MD

      response '204', 'allele deleted' do
        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:existing) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }
        let(:chromosome_id) { chromosome.id }
        let(:id) { existing.id }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/generations' do
    parameter name: :chromosome_id, in: :path, type: :integer

    get 'List generations' do
      tags 'Generations'
      produces 'application/json'
      description <<~MD
        Lists generations for a chromosome.

        A generation is a snapshot/iteration of a population of organisms.
        Use `POST /chromosomes/{chromosome_id}/generations` to create the first generation, then `procreate` to create subsequent generations.
      MD

      response '200', 'generations listed' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Generation' }

        let(:chromosome_id) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.generations.create!(iteration: 1)
          chromosome.id
        end

        run_test!
      end
    end

    post 'Create first generation' do
      tags 'Generations'
      produces 'application/json'
      description <<~MD
        Bootstraps the first generation for a chromosome.

        Behavior:
        - Allowed only if the chromosome has zero generations.
        - Creates `iteration = 1` and seeds an initial population of organisms (currently 20).

        If a generation already exists, you should use `procreate` from an existing generation instead of creating multiple "generation 1" roots.
      MD

      response '201', 'generation created' do
        schema '$ref' => '#/components/schemas/Generation'

        let(:chromosome_id) do
          Chromosome.create!(name: 'experiment 1', organization: org).id
        end

        run_test!
      end

      response '409', 'generation already exists' do
        schema '$ref' => '#/components/schemas/Errors'

        let(:chromosome_id) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.generations.create!(iteration: 1)
          chromosome.id
        end

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/generations/{id}' do
    parameter name: :chromosome_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show generation' do
      tags 'Generations'
      produces 'application/json'
      description <<~MD
        Fetches a generation record.

        Note: this endpoint returns generation metadata (id, chromosome_id). Use the organisms endpoints to inspect the population.
      MD

      response '200', 'generation found' do
        schema '$ref' => '#/components/schemas/Generation'

        let(:chromosome) { Chromosome.create!(name: 'experiment 1', organization: org) }
        let(:chromosome_id) { chromosome.id }
        let(:id) { chromosome.generations.create!(iteration: 1).id }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/generations/{id}/procreate' do
    parameter name: :chromosome_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    post 'Procreate a new generation' do
      tags 'Generations'
      produces 'application/json'
      description <<~MD
        Creates a new generation derived from a parent generation.

        This is the main "evolution" step:
        - Selects parents from the parent generation (based on fitness)
        - Produces a new population in a newly created generation

        After creating the offspring generation, update fitness values for its organisms and procreate again.
      MD

      response '201', 'offspring generation created' do
        schema '$ref' => '#/components/schemas/Generation'

        let(:chromosome) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome
        end

        let(:parent_generation) do
          generation = chromosome.generations.create!(iteration: 1)
          o1 = Organisms::Create.call(generation:).organism
          o2 = Organisms::Create.call(generation:).organism
          o1.update!(fitness: 100)
          o2.update!(fitness: 50)
          generation
        end

        let(:chromosome_id) { chromosome.id }
        let(:id) { parent_generation.id }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/generations/{generation_id}/organisms' do
    parameter name: :chromosome_id, in: :path, type: :integer
    parameter name: :generation_id, in: :path, type: :integer

    get 'List organisms' do
      tags 'Organisms'
      produces 'application/json'
      description <<~MD
        Lists organisms in a generation.

        An organism represents one candidate solution (one set of allele values).
        Use `PATCH /.../organisms/{id}` to update fitness after evaluating the organism externally.
      MD

      response '200', 'organisms listed' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Organism' }

        let(:chromosome) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome
        end
        let(:generation) do
          generation = chromosome.generations.create!(iteration: 1)
          Organisms::Create.call(generation:)
          generation
        end

        let(:chromosome_id) { chromosome.id }
        let(:generation_id) { generation.id }

        run_test!
      end
    end
  end

  path '/chromosomes/{chromosome_id}/generations/{generation_id}/organisms/{id}' do
    parameter name: :chromosome_id, in: :path, type: :integer
    parameter name: :generation_id, in: :path, type: :integer
    parameter name: :id, in: :path, type: :integer

    get 'Show organism' do
      tags 'Organisms'
      produces 'application/json'
      description <<~MD
        Fetches a single organism's current allele values.

        This is what you feed into your external evaluation (e.g., model/sampler/scheduler hyperparameters).
      MD

      response '200', 'organism found' do
        schema '$ref' => '#/components/schemas/Organism'

        let(:chromosome) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome
        end
        let(:generation) do
          generation = chromosome.generations.create!(iteration: 1)
          Organisms::Create.call(generation:)
          generation
        end
        let(:organism) { generation.organisms.first }

        let(:chromosome_id) { chromosome.id }
        let(:generation_id) { generation.id }
        let(:id) { organism.id }

        run_test!
      end
    end

    patch 'Update organism fitness' do
      tags 'Organisms'
      consumes 'application/json'
      produces 'application/json'
      description <<~MD
        Updates an organism's fitness score.

        Fitness is the signal used for selection when procreating the next generation.
        Higher fitness means the organism is more likely to be selected as a parent.
      MD
      parameter name: :organism, in: :body, schema: {
        type: :object,
        required: [:organism],
        properties: {
          organism: {
            type: :object,
            properties: {
              fitness: { type: :number }
            }
          }
        }
      }

      response '200', 'organism updated' do
        schema '$ref' => '#/components/schemas/Organism'

        let(:chromosome) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome
        end
        let(:generation) do
          generation = chromosome.generations.create!(iteration: 1)
          Organisms::Create.call(generation:)
          generation
        end
        let(:organism_record) { generation.organisms.first }

        let(:chromosome_id) { chromosome.id }
        let(:generation_id) { generation.id }
        let(:id) { organism_record.id }
        let(:organism) { { organism: { fitness: 100 } } }

        run_test!
      end

      response '400', 'missing organism param' do
        let(:chromosome) do
          chromosome = Chromosome.create!(name: 'experiment 1', organization: org)
          chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
          chromosome
        end
        let(:generation) do
          generation = chromosome.generations.create!(iteration: 1)
          Organisms::Create.call(generation:)
          generation
        end
        let(:organism_record) { generation.organisms.first }

        let(:chromosome_id) { chromosome.id }
        let(:generation_id) { generation.id }
        let(:id) { organism_record.id }
        let(:organism) { {} }

        run_test!
      end
    end
  end
end
