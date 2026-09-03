# frozen_string_literal: true

require 'rails_helper'

RSpec.describe '/chromosomes/:chromosome_id/alleles' do
  let(:organization) { FactoryBot.create(:organization) }
  let(:user) { sign_in_as(organization: organization) }
  let(:chromosome) { FactoryBot.create(:chromosome, organization: organization) }

  let(:valid_attributes) do
    { name: 'legs', type: 'Integer', minimum: 1, maximum: 50 }
  end

  let(:invalid_attributes) do
    { name: 'legs', type: 'Integer' }
  end

  before { user } # sign in via the real login flow

  describe 'GET /index' do
    it 'renders a successful response' do
      chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
      get chromosome_alleles_url(chromosome)
      expect(response).to be_successful
    end
  end

  describe 'GET /show' do
    it 'renders a successful response' do
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last
      get chromosome_allele_url(chromosome, allele)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    context 'with valid parameters' do
      it 'creates a new Allele' do
        expect do
          post chromosome_alleles_url(chromosome), params: { allele: valid_attributes }
        end.to change(Allele, :count).by(1)
      end

      it 'returns a 201 response' do
        post chromosome_alleles_url(chromosome), params: { allele: valid_attributes }
        expect(response).to have_http_status(:created)
      end
    end

    context 'with invalid parameters' do
      it 'does not create a new Allele' do
        expect do
          post chromosome_alleles_url(chromosome), params: { allele: invalid_attributes }
        end.not_to change(Allele, :count)
      end

      it 'returns 422' do
        post chromosome_alleles_url(chromosome), params: { allele: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'PATCH /update' do
    let(:allele) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }

    context 'with valid parameters' do
      it 'updates the requested allele' do
        patch chromosome_allele_url(chromosome, allele), params: { allele: { minimum: 2, maximum: 60 } }
        expect(response).to have_http_status(:ok)
        expect(allele.reload.inheritable.minimum).to eq(2)
        expect(allele.reload.inheritable.maximum).to eq(60)
      end
    end

    context 'with invalid parameters' do
      it 'rejects changing type' do
        patch chromosome_allele_url(chromosome, allele), params: { allele: { type: 'Float' } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the requested allele' do
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last
      expect do
        delete chromosome_allele_url(chromosome, allele)
      end.to change(Allele, :count).by(-1)
    end

    it 'returns 204' do
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last
      delete chromosome_allele_url(chromosome, allele)
      expect(response).to have_http_status(:no_content)
    end
  end
end
