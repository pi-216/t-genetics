# frozen_string_literal: true

require 'rails_helper'

# Chromosomes are org-scoped workspace records (PRD-0002) and require sign-in
# (finding #56, founder ruling 2026-09-04). Every example here authenticates a
# session and creates org-scoped chromosomes — anonymous access is the
# vulnerability this scaffold spec used to encode.
RSpec.describe '/chromosomes' do
  let(:organization) { FactoryBot.create(:organization) }

  # This should return the minimal set of attributes required to create a valid
  # Chromosome.
  let(:valid_attributes) do
    { name: 'foobaz', organization: organization }
  end

  let(:invalid_attributes) do
    { name: nil }
  end

  before { sign_in_as(organization: organization) }

  describe 'GET /index' do
    it 'renders a successful response' do
      Chromosome.create! valid_attributes
      get chromosomes_url
      expect(response).to be_successful
    end
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      chromosome = Chromosome.create! valid_attributes
      get chromosome_url(chromosome)
      expect(response).to be_successful
    end
  end

  describe 'GET /new' do
    it 'renders a successful response' do
      get new_chromosome_url
      expect(response).to be_successful
    end

    # Issue #163 — designer form column must keep the explicit [36rem] width
    # (spacing tokens shadow the named max-w-* scale in Tailwind v4.1).
    it 'renders the form column at the pinned [36rem] width' do
      get new_chromosome_url
      expect(response.body).to include('max-w-[36rem]')
      expect(response.body).not_to match(/max-w-(?:md|xl)/)
    end
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      chromosome = Chromosome.create! valid_attributes
      get edit_chromosome_url(chromosome)
      expect(response).to be_successful
    end

    # Finding #147 (T1) — same transport bug shape as the designer: the edit
    # form's PATCH failure re-renders :edit with a 422 that Turbo would
    # discard. The form must opt out of Turbo so inline errors display.
    it 'renders the edit form NOT turbo-enabled (data-turbo="false")' do
      chromosome = Chromosome.create! valid_attributes
      get edit_chromosome_url(chromosome)
      expect(response).to be_successful
      expect(response.body).to include('data-turbo="false"')
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new Chromosome' do
        expect do
          post chromosomes_url, params: { chromosome: valid_attributes }
        end.to change(Chromosome, :count).by(1)
      end

      it 'redirects to the created chromosome' do
        post chromosomes_url, params: { chromosome: valid_attributes }
        expect(response).to redirect_to(chromosome_url(Chromosome.last))
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Chromosome' do
        expect do
          post chromosomes_url, params: { chromosome: invalid_attributes }
        end.not_to change(Chromosome, :count)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        post chromosomes_url, params: { chromosome: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    # Finding #149: the designer must reject duplicate allele names per
    # chromosome with the same inline error channel as bounds/choices. The
    # fixture posts two cards sharing 'weight' — the command fails atomically
    # and the re-render carries the per-allele message.
    context 'with duplicate allele names in the designer payload' do
      let(:duplicate_payload) do
        {
          name: 'Dup genome',
          alleles: [
            { name: 'weight', type: 'Float', minimum: 0, maximum: 10 },
            { name: 'weight', type: 'Float', minimum: 0, maximum: 10 }
          ]
        }
      end

      it 'does not create a new Chromosome' do
        expect do
          post chromosomes_url, params: { chromosome: duplicate_payload }
        end.not_to change(Chromosome, :count)
      end

      it 'returns 422 and surfaces the per-allele error' do
        post chromosomes_url, params: { chromosome: duplicate_payload }

        expect(response).to have_http_status(:unprocessable_content)
        # The rendered message is HTML-escaped (&#39;) so the literal
        # "allele 'weight':" prefix never appears — assert the inline
        # .allele-error surface and the stripped per-allele message.
        expect(response.body).to include('allele-error')
        expect(response.body).to include('name is already used on this chromosome')
      end
    end

    # Finding #149: the uniqueness scope is the chromosome — the same allele
    # name posted against two different chromosomes must succeed both times.
    context 'with the same allele name on two different chromosomes' do
      let(:payload) do
        { name: 'Genome', alleles: [{ name: 'weight', type: 'Float', minimum: 0, maximum: 10 }] }
      end

      it 'creates both chromosomes' do
        post chromosomes_url, params: { chromosome: payload }
        expect(response).to have_http_status(:found)

        post chromosomes_url, params: { chromosome: payload }
        expect(response).to have_http_status(:found)

        expect(Chromosome.where(name: 'Genome').count).to eq(2)
        expect(Chromosome.where(name: 'Genome').flat_map { |c| c.alleles.map(&:name) }).to eq(%w[weight weight])
      end
    end
  end

  describe 'PATCH /update' do
    context 'with valid parameters' do
      let(:new_attributes) do
        { name: 'baz' }
      end

      it 'updates the requested chromosome' do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: new_attributes }
        chromosome.reload
        expect(chromosome.name).to eq('baz')
      end

      it 'redirects to the chromosome' do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: new_attributes }
        chromosome.reload
        expect(response).to redirect_to(chromosome_url(chromosome))
      end
    end

    context 'with invalid parameters' do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested chromosome' do
      chromosome = Chromosome.create! valid_attributes
      expect do
        delete chromosome_url(chromosome)
      end.to change(Chromosome, :count).by(-1)
    end

    it 'redirects to the chromosomes list' do
      chromosome = Chromosome.create! valid_attributes
      delete chromosome_url(chromosome)
      expect(response).to redirect_to(chromosomes_url)
    end
  end
end
