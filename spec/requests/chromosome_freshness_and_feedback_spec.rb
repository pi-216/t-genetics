# frozen_string_literal: true

require 'rails_helper'

# Issue #209 — allele and chromosome mutations redirect back to the show page,
# but the page came back stale and confirmed nothing:
#   1. `fresh_when(@chromosome)` builds the ETag from the chromosome row alone
#      (`ActiveSupport::Cache.expand_cache_key` folds the record's
#      `cache_key_with_version` in) and neither `has_many :alleles` nor
#      `has_many :generations` touched its parent, so a browser holding the
#      cached page revalidated with unchanged validators, got a 304 and kept
#      the pre-mutation list. The index page has the same shape — it renders
#      per-chromosome allele and generation counts while its ETag is
#      MAX(chromosomes.updated_at).
#   2. No mutation set a success notice and the shared layout rendered no
#      flash at all, so even a fresh render confirmed nothing.
RSpec.describe 'Chromosome mutation freshness and feedback (issue #209)', type: :request do
  let(:organization) { FactoryBot.create(:organization) }
  let(:chromosome) { FactoryBot.create(:chromosome, organization: organization) }

  before { sign_in_as(organization: organization) }

  # The validators a browser would hold for the page it is looking at. The
  # first GET also carries the sign-in flash — `etag_with_flash` folds the
  # flash into the ETag — so warm the cache before capturing them.
  def cached_validators(path)
    get path
    get path
    { 'If-None-Match' => response.headers['ETag'],
      'If-Modified-Since' => response.headers['Last-Modified'] }
  end

  def add_integer_allele(chromosome, name: 'legs', minimum: 2, maximum: 4)
    post chromosome_alleles_url(chromosome),
         params: { allele: { name:, type: 'Integer', minimum:, maximum: } },
         as: :html
  end

  def integer_allele_on(chromosome, name: 'legs', minimum: 2, maximum: 4)
    (chromosome.alleles << Allele.new_with_integer(name:, minimum:, maximum:)).last
  end

  def rename_allele(chromosome, allele, name: 'limbs')
    patch chromosome_allele_url(chromosome, allele),
          params: { allele: { name:, minimum: 2, maximum: 4 } }, as: :html
  end

  describe 'revalidation after an allele is added' do
    it 'serves the show page with 200 and the new allele, never a stale 304' do
      validators = cached_validators(chromosome_url(chromosome))

      add_integer_allele(chromosome)
      follow_redirect!
      get chromosome_url(chromosome), headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('legs')
      end
    end

    it 'serves the index page with 200 and the new allele count' do
      existing = FactoryBot.create(:chromosome, organization: organization)
      validators = cached_validators(chromosomes_url)

      add_integer_allele(existing)
      follow_redirect!
      get chromosomes_url, headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('1 allele')
      end
    end

    it 'serves the show page with 200 after a generation was created' do
      validators = cached_validators(chromosome_url(chromosome))

      FactoryBot.create(:generation, chromosome: chromosome)
      get chromosome_url(chromosome), headers: validators

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'revalidation after an allele is edited or deleted' do
    it 'serves the show page with 200 after the allele was renamed' do
      allele = integer_allele_on(chromosome)
      validators = cached_validators(chromosome_url(chromosome))

      rename_allele(chromosome, allele)
      follow_redirect!
      get chromosome_url(chromosome), headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('limbs')
      end
    end

    it 'serves the show page with 200 after the allele was deleted' do
      allele = integer_allele_on(chromosome)
      validators = cached_validators(chromosome_url(chromosome))

      delete chromosome_allele_url(chromosome, allele), as: :html
      follow_redirect!
      get chromosome_url(chromosome), headers: validators

      aggregate_failures do
        expect(response).to have_http_status(:ok)
        expect(response.body).to include('No alleles yet')
      end
    end
  end

  describe 'success feedback on the page each mutation redirects to' do
    it 'confirms an added allele' do
      add_integer_allele(chromosome)
      follow_redirect!

      expect(response.body).to include('Added allele legs.')
    end

    it 'confirms an updated allele' do
      rename_allele(chromosome, integer_allele_on(chromosome))
      follow_redirect!

      expect(response.body).to include('Updated allele limbs.')
    end

    it 'confirms a deleted allele' do
      delete chromosome_allele_url(chromosome, integer_allele_on(chromosome)), as: :html
      follow_redirect!

      expect(response.body).to include('Deleted allele legs.')
    end

    it 'confirms a created chromosome' do
      post chromosomes_url, params: { chromosome: { name: 'Bare genome' } }, as: :html
      follow_redirect!

      expect(response.body).to include('Created chromosome Bare genome.')
    end

    it 'confirms an updated chromosome' do
      patch chromosome_url(chromosome), params: { chromosome: { name: 'Renamed genome' } }, as: :html
      follow_redirect!

      expect(response.body).to include('Updated chromosome Renamed genome.')
    end

    it 'confirms a deleted chromosome' do
      delete chromosome_url(chromosome), as: :html
      follow_redirect!

      expect(response.body).to include("Deleted chromosome #{chromosome.name}.")
    end

    # `touch: true` fires from the child's after_destroy while the parent row
    # still exists (dependent: :destroy runs before the parent's delete) —
    # this pins that ordering so a future touch-on-destroy change cannot raise.
    it 'destroys a chromosome that still has alleles and generations' do
      integer_allele_on(chromosome)
      FactoryBot.create(:generation, chromosome: chromosome)

      expect { delete chromosome_url(chromosome), as: :html }.to change(Chromosome, :count).by(-1)

      aggregate_failures do
        expect(Allele.count).to eq(0)
        expect(Generation.count).to eq(0)
        expect(response).to redirect_to(chromosomes_url)
      end
    end
  end
end
