# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Organisms", type: :request do
  describe "GET /chromosomes/:chromosome_id/generations/:generation_id/organisms" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { sign_in_as(organization: organization) }
    let(:chromosome) { FactoryBot.create(:chromosome, organization: organization) }
    let(:generation) { FactoryBot.create(:generation, chromosome: chromosome) }
    let!(:organism) { Organisms::Create.call(generation: generation).organism }

    before { user }

    it "includes the id in the response" do
      get chromosome_generation_organisms_path(chromosome, generation), headers: { 'ACCEPT' => 'application/json' }
      
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first).to have_key("id")
      expect(json_response.first["id"]).to eq(organism.id)
    end
  end

  # PRD-0004 DEV-0005 (issue #81) — a member opens an organism from the
  # generation browser and sees each value rendered by its allele type:
  # booleans as true/false badges, floats/integers with their bounds. The
  # HTML viewer is org-scoped through the chromosome (cross-org/unknown ids
  # answer 404 — never data); the JSON shape API clients use is unchanged.
  describe "GET /chromosomes/:chromosome_id/generations/:generation_id/organisms/:id (HTML viewer)" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { sign_in_as(organization: organization) }

    # Mixed allele types (float/int/bool) so each value renders by its type.
    # The chromosome is reloaded after adding alleles: the after_initialize
    # hook caches the (then empty) allele collection on the instance, and
    # Organisms::Create would otherwise birth values from a stale empty
    # collection.
    let(:chromosome) do
      built = FactoryBot.create(:chromosome, organization: organization)

      float_allele = Allele.new_with_float(name: 'size', minimum: 0.0, maximum: 1.0)
      float_allele.chromosome = built
      float_allele.save!
      integer_allele = Allele.new_with_integer(name: 'count', minimum: 1, maximum: 10)
      integer_allele.chromosome = built
      integer_allele.save!
      boolean_allele = Allele.new_with_boolean(name: 'enabled')
      boolean_allele.chromosome = built
      boolean_allele.save!
      option_allele = Allele.new_with_option(name: 'color', choices: %w[red blue])
      option_allele.chromosome = built
      option_allele.save!

      built.reload
    end

    let(:generation) { FactoryBot.create(:generation, chromosome: chromosome) }
    let!(:organism) do
      created = Organisms::Create.call(generation: generation).organism
      # The engine births values with nil data — materialize typed data
      # through its own mutation path (Valuable#mutate!), exactly like an
      # evolved generation's values would look.
      created.values.to_a.each(&:mutate!)
      created.reload
    end

    let(:organism_path) { chromosome_generation_organism_path(chromosome, generation, organism) }

    before { user }

    it "renders each value by its allele type" do
      get organism_path
      expect(response).to have_http_status(:success)

      values = organism.values.includes(:allele).sort_by { |v| v.allele.name }
      expect(values.map { |v| v.allele.type }).to contain_exactly('Float', 'Integer', 'Boolean', 'Option')
      values.each { |value| expect_typed_row_for(value, response.body) }
    end

    it "answers 404 for a member of another organization (org scoping red line)" do
      sign_in_as(organization: FactoryBot.create(:organization))
      get organism_path
      expect(response).to have_http_status(:not_found)
    end

    it "answers 404 when the organism does not exist" do
      get chromosome_generation_organism_path(chromosome, generation, 999_999)
      expect(response).to have_http_status(:not_found)
    end

    it "keeps serving the JSON shape for API clients" do
      get organism_path, headers: { 'ACCEPT' => 'application/json' }
      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to include('id' => organism.id)
    end

    # One value's full typed-rendering contract: its row carries the type in
    # the class and data attributes, booleans render as a true/false badge,
    # numeric types (float/integer) annotate their hereditable bounds, and
    # options render the chosen choice.
    def expect_typed_row_for(value, body)
      type = value.allele.type.downcase
      expect(body).to include("value-row value-#{type}")
      expect(body).to include(%(data-allele="#{value.allele.name}"))
      expect(body).to include(%(data-type="#{type}"))

      if value.allele.type == 'Boolean'
        expect(body).to match(%r{<span class="value-badge">(true|false)</span>})
      elsif %w[Float Integer].include?(value.allele.type)
        expect(body).to include('value-bounds')
        expect(body).to match(/bounds/)
      else
        expect(body).to include('<span class="value-data">')
      end
    end
  end
end
