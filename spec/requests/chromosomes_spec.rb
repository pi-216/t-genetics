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
  end

  describe 'GET /edit' do
    it 'renders a successful response' do
      chromosome = Chromosome.create! valid_attributes
      get edit_chromosome_url(chromosome)
      expect(response).to be_successful
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
