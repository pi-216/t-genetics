# frozen_string_literal: true

require 'rails_helper'

# Issue #215 — a write to an organism's value leaves the responses that render
# those values revalidating unchanged:
#   * `fresh_when(organisms)` (the JSON index) keys on MAX(organisms.updated_at)
#     while the payload is built from the organisms' `values`;
#   * `fresh_when(etag: [@organism, @recorded_fitness.to_s])` (the viewer) folds
#     in the recorded fitness (issue #170) but not the values.
# `Value belongs_to :organism` carried no touch, so neither key moved and a
# revalidating client revalidated, got a 304 and kept the pre-write values.
# Same class as #209 (allele/generation -> chromosome); this is the
# organism/value carrier for it.
RSpec.describe 'Organism value freshness (issue #215)', type: :request do
  let(:organization) { FactoryBot.create(:organization) }

  # The chromosome is reloaded after the allele is added: the after_initialize
  # hook caches the (then empty) allele collection on the instance, and
  # Organisms::Create would otherwise birth values from that stale collection.
  let(:chromosome) do
    built = FactoryBot.create(:chromosome, organization: organization)
    allele = Allele.new_with_float(name: 'size', minimum: 0.0, maximum: 1.0)
    allele.chromosome = built
    allele.save!
    built.reload
  end

  let(:generation) { FactoryBot.create(:generation, chromosome: chromosome) }
  let!(:organism) { Organisms::Create.call(generation: generation).organism }

  let(:index_path) { chromosome_generation_organisms_path(chromosome, generation) }
  let(:viewer_path) { chromosome_generation_organism_path(chromosome, generation, organism) }

  before { sign_in_as(organization: organization) }

  # The validators a client would hold for the page it is looking at. The first
  # GET carries the sign-in flash — `etag_with_flash` folds the flash into the
  # ETag — so warm the cache before capturing them.
  def cached_validators(path, accept: nil)
    headers = accept ? { 'ACCEPT' => accept } : {}
    get path, headers: headers
    get path, headers: headers
    { 'If-None-Match' => response.headers['ETag'],
      'If-Modified-Since' => response.headers['Last-Modified'] }
  end

  def value_of(organism, name)
    organism.values.by_name(name).first
  end

  describe 'revalidation after a value is written through Organisms::SetValue' do
    it 'serves the JSON index with 200 and the new value, never a stale 304' do
      validators = cached_validators(index_path, accept: 'application/json')

      Organisms::SetValue.call(organism: organism, name: 'size', value: 0.42)
      get index_path, headers: validators.merge('ACCEPT' => 'application/json')

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.first['size']).to eq(0.42)
      end
    end

    it 'serves the organism viewer with 200 and the new value, never a stale 304' do
      validators = cached_validators(viewer_path)

      Organisms::SetValue.call(organism: organism, name: 'size', value: 0.42)
      get viewer_path, headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('0.42')
      end
    end
  end

  # The other half of the same contract: an unchanged surface must answer 304,
  # not a 500. `fresh_when` renders the 304 itself (`head :not_modified` when the
  # request is fresh) and both actions then rendered explicitly, so every fresh
  # conditional GET raised AbstractController::DoubleRenderError — a revalidating
  # client got a 500 where a 304 was due.
  describe 'an unchanged surface revalidates as 304' do
    it 'answers 304 for the JSON index' do
      validators = cached_validators(index_path, accept: 'application/json')

      get index_path, headers: validators.merge('ACCEPT' => 'application/json')

      expect(response).to have_http_status(:not_modified)
    end

    it 'answers 304 for the viewer JSON shape' do
      validators = cached_validators(viewer_path, accept: 'application/json')

      get viewer_path, headers: validators.merge('ACCEPT' => 'application/json')

      expect(response).to have_http_status(:not_modified)
    end

    it 'answers 304 for the HTML viewer' do
      validators = cached_validators(viewer_path)

      get viewer_path, headers: validators

      expect(response).to have_http_status(:not_modified)
    end
  end

  describe 'revalidation after a value mutates through Value#mutate!' do
    it 'serves the JSON index with 200 and the mutated value' do
      validators = cached_validators(index_path, accept: 'application/json')

      value_of(organism, 'size').mutate!
      mutated = value_of(organism.reload, 'size').data

      get index_path, headers: validators.merge('ACCEPT' => 'application/json')

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body.first['size']).to eq(mutated)
      end
    end

    it 'serves the organism viewer with 200 and the mutated value' do
      validators = cached_validators(viewer_path)

      value_of(organism, 'size').mutate!
      mutated = value_of(organism.reload, 'size').data

      get viewer_path, headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include(mutated.to_s)
      end
    end
  end
end
