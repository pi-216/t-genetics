# frozen_string_literal: true

require 'rails_helper'

# Org-scoping of chromosome access (PRD-0002 DEV-0009 / issue #19).
# Cross-org access must return 404 and must never disclose another org's
# chromosome — server-side enforcement on every chromosome query.
RSpec.describe 'Org-scoped chromosome access', type: :request do
  let!(:alpha_org) { FactoryBot.create(:organization, name: 'Alpha') }
  let!(:beta_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:alpha_chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: alpha_org) }
  let!(:beta_chromosome) { FactoryBot.create(:chromosome, name: 'Beta-chrom', organization: beta_org) }

  describe 'GET /chromosomes/:id' do
    context 'when signed in as a partner of another organization' do
      before { sign_in_as(organization: beta_org) }

      it 'returns 404 for a chromosome owned by a different org' do
        get chromosome_url(alpha_chromosome)

        expect(response).to have_http_status(:not_found)
      end

      it 'does not disclose the chromosome name in the API response body' do
        get chromosome_url(alpha_chromosome), headers: { 'ACCEPT' => 'application/json' }

        expect(response).to have_http_status(:not_found)
        expect(response.body).not_to include('Alpha-chrom')
      end
    end

    context 'when signed in as a member of the owning organization' do
      before { sign_in_as(organization: alpha_org) }

      it 'serves the chromosome' do
        get chromosome_url(alpha_chromosome)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe 'GET /chromosomes' do
    it 'only lists chromosomes of the signed-in user\'s organization' do
      sign_in_as(organization: beta_org)

      get chromosomes_url

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(beta_chromosome.name)
      expect(response.body).not_to include('Alpha-chrom')
    end
  end

  describe 'PATCH /chromosomes/:id' do
    it 'returns 404 when updating another org\'s chromosome' do
      sign_in_as(organization: beta_org)

      patch chromosome_url(alpha_chromosome), params: { chromosome: { name: 'hijacked' } }

      expect(response).to have_http_status(:not_found)
      expect(alpha_chromosome.reload.name).to eq('Alpha-chrom')
    end
  end

  describe 'DELETE /chromosomes/:id' do
    it 'returns 404 when deleting another org\'s chromosome' do
      sign_in_as(organization: beta_org)

      expect do
        delete chromosome_url(alpha_chromosome)
      end.not_to change(Chromosome, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
