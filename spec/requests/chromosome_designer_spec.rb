# frozen_string_literal: true

require 'rails_helper'

# PRD-0004 DEV-0001 (issue #77) — the chromosome designer: a single-surface
# page where a member creates a chromosome with typed allele cards (name +
# type + type-specific fields), sees a live preview of the allele set as it is
# built, and submits to an org-scoped create. Designer mutations must go
# through a command (PRD-0004 edge-case red line), never direct model writes.
RSpec.describe '/chromosomes — designer create (DEV-0001)' do
  let(:organization) { FactoryBot.create(:organization) }
  let(:mixed_allele_params) do
    [
      { name: 'weight', type: 'Float', minimum: '0', maximum: '10' },
      { name: 'limbs', type: 'Integer', minimum: '2', maximum: '4' },
      { name: 'wings', type: 'Boolean' }
    ]
  end

  before { sign_in_as(organization: organization) }

  describe 'GET /new (the designer surface)' do
    it 'renders the designer with one blank allele card and a preview section' do
      get new_chromosome_url
      expect(response).to be_successful
      expect(response.body).to include('allele-card')
      expect(response.body).to include('allele-preview')
    end
  end

  describe 'POST /chromosomes (designer create)' do
    context 'with mixed allele types' do
      it 'creates a chromosome with all three typed alleles under the org' do
        expect do
          post chromosomes_url,
               params: { chromosome: { name: 'Mixed genome', alleles: mixed_allele_params } }
        end.to change(Chromosome, :count).by(1)

        chromosome = Chromosome.last
        expect(chromosome.organization).to eq(organization)
        expect(chromosome.alleles.map(&:name)).to match_array(%w[weight limbs wings])
        expect(chromosome.alleles.map(&:type)).to match_array(%w[Float Integer Boolean])
      end

      it 'redirects to the chromosome show page (the live preview)' do
        post chromosomes_url,
             params: { chromosome: { name: 'Mixed genome', alleles: mixed_allele_params } }
        expect(response).to redirect_to(chromosome_url(Chromosome.last))
      end

      it 'renders a 422 and no row when the chromosome name is blank' do
        expect do
          post chromosomes_url,
               params: { chromosome: { name: '', alleles: mixed_allele_params } }
        end.not_to change(Chromosome, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'with an unknown allele type' do
      it 'renders a 422 and creates nothing (atomic designer create)' do
        bad = mixed_allele_params + [{ name: 'bogus', type: 'Mystery' }]
        expect do
          post chromosomes_url, params: { chromosome: { name: 'Mixed genome', alleles: bad } }
        end.not_to change(Chromosome, :count)
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when creating without alleles (legacy CRUD compatibility)' do
      it 'still creates a chromosome without alleles' do
        expect do
          post chromosomes_url, params: { chromosome: { name: 'Bare' } }
        end.to change(Chromosome, :count).by(1)
        expect(Chromosome.last.alleles).to be_empty
      end
    end

    # PRD-0004 DEV-0002 (issue #78): a reversed bound is an inline validation
    # error on the re-rendered designer, and nothing is saved.
    context 'with an allele whose minimum exceeds its maximum' do
      it 'renders a 422 with an inline per-card error and creates nothing' do
        expect do
          post chromosomes_url,
               params: { chromosome: { name: 'Bounded genome',
                                       alleles: [{ name: 'weight', type: 'Float', minimum: '10', maximum: '1' }] } }
        end.not_to change(Chromosome, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('allele-error')
        expect(response.body).to match(/less than or equal/i)
        # The per-card .allele-error renders the STRIPPED message (no
        # "allele 'weight':" prefix — the prefix stays in the top-level
        # .command-errors summary only).
        expect(response.body).to match(%r{<div class="allele-error">\s*minimum \(10\) must be less than or equal to maximum \(1\)\s*</div>})
      end
    end

    # PRD-0004 DEV-0003 (issue #79): an option allele with an empty choice
    # list is an inline validation error on the re-rendered designer, and
    # nothing is saved. The message must carry the "allele '<name>':" prefix
    # so the per-card .allele-error matcher picks it up (mirror of the
    # DEV-0002 bounds case above).
    context 'with an option allele whose choice list is empty' do
      it 'renders a 422 with an inline per-card error and creates nothing' do
        expect do
          post chromosomes_url,
               params: { chromosome: { name: 'Option genome',
                                       alleles: [{ name: 'flavor', type: 'Option', choices: '' }] } }
        end.not_to change(Chromosome, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include('allele-error')
        expect(response.body).to match(/choice list must not be empty/i)
        # The per-card .allele-error renders the STRIPPED message (no
        # "allele 'flavor':" prefix).
        expect(response.body).to match(%r{<div class="allele-error">\s*choice list must not be empty\s*</div>})
      end
    end
  end

  describe 'GET /chromosomes/:id (live preview on the show page)' do
    it 'renders the saved allele set as the preview' do
      post chromosomes_url,
           params: { chromosome: { name: 'Mixed genome', alleles: mixed_allele_params } }
      chromosome = Chromosome.last

      get chromosome_url(chromosome)
      expect(response).to be_successful
      expect(response.body).to include('allele-preview')
      expect(response.body).to include('weight', 'limbs', 'wings')
    end
  end
end
