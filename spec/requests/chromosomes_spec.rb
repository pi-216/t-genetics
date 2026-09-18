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

    # Issue #184 — PO ruling 2026-09-15: creation is name-only; the
    # duplicate-allele-name rule moved with the alleles to the nested
    # /chromosomes/:id/alleles endpoint (covered in alleles_spec.rb).
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

      # Issue #207 — the controller must route the mutation through the command
      # layer (no raw `@chromosome.update` in the controller): the command owns
      # the write, the controller only maps its result onto a format.
      it 'routes the mutation through Chromosomes::Update' do
        chromosome = Chromosome.create! valid_attributes

        expect(Chromosomes::Update).to receive(:call).and_call_original
        patch chromosome_url(chromosome), params: { chromosome: new_attributes }
      end

      it 'renders the updated chromosome as JSON' do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: new_attributes }, as: :json

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body['name']).to eq('baz')
      end
    end

    context 'with invalid parameters' do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end

      # Issue #207 — deliberate, verified deviation: the pre-command action ran
      # `@chromosome.update(permitted)` and a PATCH carrying only unpermitted
      # attributes was a no-op SUCCESS (302 + "Updated chromosome"). The command
      # takes the name explicitly, so that shape now reports the missing name
      # instead of confirming an update that never happened. (`chromosome: {}`
      # is a 400 before and after — `require` rejects an empty value.)
      it 'reports the missing name when the PATCH carries only unpermitted attributes' do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: { bogus: 'ignored' } }

        expect(response).to have_http_status(:unprocessable_content)
        expect(chromosome.reload.name).to eq('foobaz')
      end

      # Issue #207 — the JSON error body is the same `{ errors: { name: [...] } }`
      # shape the web form has always returned (the rswag path documents it).
      it 'returns the unchanged JSON error body' do
        chromosome = Chromosome.create! valid_attributes
        patch chromosome_url(chromosome), params: { chromosome: invalid_attributes }, as: :json

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq({ 'errors' => { 'name' => ["can't be blank"] } })
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
