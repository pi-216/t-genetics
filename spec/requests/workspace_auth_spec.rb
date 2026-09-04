# frozen_string_literal: true

require 'rails_helper'

# Anonymous access to the workspace (finding #56, founder ruling 2026-09-04).
# Chromosomes/alleles/generations/organisms are org-scoped workspace routes:
# they require sign-in. Anonymous requests are redirected to the login page
# and must never return org data — including legacy org-less chromosomes.
RSpec.describe 'Workspace authentication', type: :request do
  let(:org) { FactoryBot.create(:organization) }
  let!(:chromosome) { FactoryBot.create(:chromosome, organization: org) }
  let!(:generation) { FactoryBot.create(:generation, chromosome:) }
  let!(:legacy_chromosome) { FactoryBot.create(:chromosome, name: 'legacy-org-less', organization: nil) }

  describe 'anonymous access' do
    it 'redirects GET /chromosomes to the login page' do
      get chromosomes_path

      expect(response).to redirect_to(login_path)
    end

    it 'redirects GET /chromosomes/:id to the login page' do
      get chromosome_path(chromosome)

      expect(response).to redirect_to(login_path)
    end

    it 'redirects GET /chromosomes/:id/alleles to the login page' do
      get chromosome_alleles_path(chromosome)

      expect(response).to redirect_to(login_path)
    end

    it 'redirects GET /chromosomes/:id/generations to the login page' do
      get chromosome_generations_path(chromosome)

      expect(response).to redirect_to(login_path)
    end

    it 'redirects GET /chromosomes/:id/generations/:generation_id/organisms to the login page' do
      get chromosome_generation_organisms_path(chromosome, generation)

      expect(response).to redirect_to(login_path)
    end

    it 'redirects POST /chromosomes to the login page and creates nothing' do
      expect do
        post chromosomes_path, params: { chromosome: { name: 'anon-created' } }
      end.not_to change(Chromosome, :count)

      expect(response).to redirect_to(login_path)
    end

    it 'never discloses a legacy org-less chromosome' do
      get chromosome_path(legacy_chromosome)

      expect(response).to redirect_to(login_path)
    end
  end

  describe 'signed-in access' do
    before { sign_in_as(organization: org) }

    it 'still lists own-org chromosomes' do
      get chromosomes_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(chromosome.name)
    end
  end
end
