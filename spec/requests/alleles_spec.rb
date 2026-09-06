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

    # PRD-0004 DEV-0002 (issue #78): the bounds rule is server-side truth —
    # the machine path must reject a reversed bound exactly like the designer.
    context 'with a minimum greater than the maximum (bounds rule)' do
      it 'does not create the Allele and returns 422' do
        expect do
          post chromosome_alleles_url(chromosome),
               params: { allele: { name: 'legs', type: 'Integer', minimum: 50, maximum: 1 } }
        end.not_to change(Allele, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/less than or equal/i)
      end
    end

    # PRD-0004 DEV-0003 (issue #79): the option-allele choice-list rule is
    # server-side truth — a blank-only choices array slips past the field-
    # presence guard ([''] is not blank) and must be stopped by the model
    # rule via the inheritable.valid? check, exactly like a reversed bound.
    context 'with an option allele whose choices are blank-only' do
      it 'does not create the Allele and returns 422' do
        expect do
          post chromosome_alleles_url(chromosome),
               params: { allele: { name: 'flavor', type: 'Option', choices: [''] } }
        end.not_to change(Allele, :count)
        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to match(/must not be empty/i)
      end

      it 'still rejects a wholly missing choices array' do
        expect do
          post chromosome_alleles_url(chromosome),
               params: { allele: { name: 'flavor', type: 'Option' } }
        end.not_to change(Allele, :count)
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

      it 'rejects reversing the bounds (minimum above maximum)' do
        patch chromosome_allele_url(chromosome, allele), params: { allele: { minimum: 60, maximum: 2 } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(allele.reload.inheritable.minimum).to eq(1)
        expect(allele.reload.inheritable.maximum).to eq(50)
      end
    end

    # PRD-0004 DEV-0003 (issue #79): the machine path must not be able to
    # clear an option allele's choices (or reduce them to blanks) — the same
    # choice-list rule applies on PATCH via update! RecordInvalid.
    context 'with an option allele and invalid choices' do
      let(:option_allele) do
        (chromosome.alleles << Allele.new_with_option(name: 'flavor', choices: %w[chocolate vanilla])).last
      end

      it 'rejects clearing all choices' do
        patch chromosome_allele_url(chromosome, option_allele), params: { allele: { choices: [] } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(option_allele.reload.inheritable.choices).to eq(%w[chocolate vanilla])
      end

      it 'rejects blank-only choices' do
        patch chromosome_allele_url(chromosome, option_allele), params: { allele: { choices: ['', ' '] } }
        expect(response).to have_http_status(:unprocessable_content)
        expect(option_allele.reload.inheritable.choices).to eq(%w[chocolate vanilla])
      end

      it 'accepts replacing choices with a non-empty list' do
        patch chromosome_allele_url(chromosome, option_allele), params: { allele: { choices: %w[red blue] } }
        expect(response).to have_http_status(:ok)
        expect(option_allele.reload.inheritable.choices).to eq(%w[red blue])
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
