# frozen_string_literal: true

require 'rails_helper'

# Issue #184 — PO ruling 2026-09-15: standard CRUD operations for chromosome
# + allele management replace the PRD-0004 single-surface designer. A
# chromosome is created by name only; alleles are managed from the show page
# through their own new/edit forms (each mutation redirecting back to the
# chromosome show page). The machine JSON allele contract is unchanged and
# pinned by alleles_spec.rb.
RSpec.describe '/chromosomes — standard CRUD web flow', type: :request do
  let(:organization) { FactoryBot.create(:organization) }

  before { sign_in_as(organization: organization) }

  describe 'GET /chromosomes/new (name-only create)' do
    it 'renders a name-only form' do
      get new_chromosome_url
      expect(response).to be_successful
      expect(response.body).to include('chromosome_name')
    end

    # Issue #184 — the designer's allele cards and live preview are gone:
    # the create surface is a plain name field, nothing else.
    it 'renders no allele cards and no allele preview' do
      get new_chromosome_url
      expect(response).to be_successful
      expect(response.body).not_to include('allele-card', 'allele-preview')
    end

    it 'keeps the pinned [36rem] column width' do
      get new_chromosome_url
      expect(response.body).to include('max-w-[36rem]')
      expect(response.body).not_to match(/max-w-(?:md|xl)/)
    end
  end

  describe 'POST /chromosomes (name-only create)' do
    it 'creates a chromosome by name and redirects to its show page' do
      expect do
        post chromosomes_url, params: { chromosome: { name: 'Bare genome' } }
      end.to change(Chromosome, :count).by(1)

      expect(response).to redirect_to(chromosome_url(Chromosome.last))
    end

    it 'ignores legacy inline allele cards in the request (create is name-only)' do
      expect do
        post chromosomes_url,
             params: { chromosome: { name: 'Bare genome',
                                     alleles: [{ name: 'legs', type: 'Integer', minimum: 1, maximum: 50 }] } }
      end.to change(Chromosome, :count).by(1)

      expect(Chromosome.last.alleles).to be_empty
    end
  end

  describe 'GET /chromosomes/:id (show page)' do
    it 'renders an empty allele state with an add action when no alleles exist' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      get chromosome_url(chromosome)
      expect(response).to be_successful
      expect(response.body).to include('No alleles yet')
      expect(response.body).to include(new_chromosome_allele_path(chromosome))
    end

    it 'lists alleles with edit and destroy actions when alleles exist' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last

      get chromosome_url(chromosome)
      expect(response).to be_successful
      expect(response.body).to include('legs')
      expect(response.body).to include(edit_chromosome_allele_path(chromosome, allele))
      expect(response.body).to include('Delete')
    end
  end

  describe 'GET /chromosomes/:id/alleles/new (the allele form)' do
    it 'renders a type-aware allele form scoped to the chromosome' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      get new_chromosome_allele_url(chromosome)
      expect(response).to be_successful
      expect(response.body).to include('New allele')
      expect(response.body).to include('allele[name]')
    end

    # Issue #203 — the back link is a text affordance in the heading block and
    # must left-align with the kicker/title; the button kit's px-4 default
    # indented it 16px. The @javascript BDD scenario measures the real left
    # edges in headless Chrome; this is the non-JS net over the rendered
    # class list.
    it 'renders the page-header back link flush-left' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      get new_chromosome_allele_url(chromosome)
      back_link = Nokogiri::HTML(response.body).at_css('.page-header a')
      expect(back_link).not_to be_nil
      expect(back_link['class']).to include('pl-0')
    end

    it 'opts the form out of Turbo so 422 re-renders display' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      get new_chromosome_allele_url(chromosome)
      expect(response.body).to include('data-turbo="false"')
    end
  end

  describe 'POST /chromosomes/:id/alleles (HTML create)' do
    it 'creates the allele and redirects back to the chromosome show page' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      expect do
        post chromosome_alleles_url(chromosome),
             params: { allele: { name: 'legs', type: 'Integer', minimum: 2, maximum: 4 } },
             as: :html
      end.to change(Allele, :count).by(1)

      expect(response).to redirect_to(chromosome_url(chromosome))
      expect(chromosome.reload.alleles.map(&:name)).to eq(%w[legs])
    end

    it 'renders the form with 422 and creates nothing when a field is missing' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      expect do
        post chromosome_alleles_url(chromosome),
             params: { allele: { name: 'legs', type: 'Integer' } },
             as: :html
      end.not_to change(Allele, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('is required')
    end

    # Issue #208 — an allele-level model failure (the record's own error, not the
    # inheritable's) must reach the name field inline, now that the command
    # rather than the controller decides it.
    it 're-renders the name field with the uniqueness rule inline' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 2, maximum: 4)

      expect do
        post chromosome_alleles_url(chromosome),
             params: { allele: { name: 'legs', type: 'Integer', minimum: 2, maximum: 4 } },
             as: :html
      end.not_to change(Allele, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('field-error')
      expect(response.body).to include('has already been taken')
    end
  end

  describe 'GET /chromosomes/:id/alleles/:id/edit' do
    it 'renders the edit form with the allele values' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 2, maximum: 4)).last

      get edit_chromosome_allele_url(chromosome, allele), as: :html
      expect(response).to be_successful
      expect(response.body).to include('legs')
    end
  end

  describe 'PATCH /chromosomes/:id/alleles/:id (HTML update)' do
    it 'updates the allele and redirects to the chromosome show page' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 2, maximum: 4)).last

      patch chromosome_allele_url(chromosome, allele),
            params: { allele: { name: 'limbs', minimum: 3, maximum: 5 } },
            as: :html

      expect(response).to redirect_to(chromosome_url(chromosome))
      expect(allele.reload.name).to eq('limbs')
      expect(allele.reload.inheritable.minimum).to eq(3)
      expect(allele.reload.inheritable.maximum).to eq(5)
    end
  end

  describe 'DELETE /chromosomes/:id/alleles/:id (HTML destroy)' do
    it 'destroys the allele and redirects to the chromosome show page' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 2, maximum: 4)).last

      expect do
        delete chromosome_allele_url(chromosome, allele), as: :html
      end.to change(Allele, :count).by(-1)

      expect(response).to redirect_to(chromosome_url(chromosome))
      expect(chromosome.reload.alleles).to be_empty
    end
  end

  # Issue #210 — the web form posts choices as ONE comma-separated string (a
  # single text input), unlike the machine contract which sends an array.
  # Strong params must permit the scalar or an Option allele can never be
  # created through the browser ("choices is required" every time).
  describe 'POST /chromosomes/:id/alleles (HTML create, Option type)' do
    it 'creates the Option allele from the comma-separated choices field' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      expect do
        post chromosome_alleles_url(chromosome),
             params: { allele: { name: 'color', type: 'Option', choices: 'red, blue' } },
             as: :html
      end.to change(Allele, :count).by(1)

      expect(response).to redirect_to(chromosome_url(chromosome))
      allele = chromosome.reload.alleles.sole
      expect(allele.type).to eq('Option')
      expect(allele.inheritable.choices).to eq(%w[red blue])
    end
  end

  describe 'PATCH /chromosomes/:id/alleles/:id (HTML update, Option type)' do
    it 'replaces the choices from the comma-separated choices field' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_option(name: 'color', choices: %w[red blue])).last

      patch chromosome_allele_url(chromosome, allele),
            params: { allele: { name: 'color', choices: 'green, yellow' } },
            as: :html

      expect(response).to redirect_to(chromosome_url(chromosome))
      expect(allele.reload.inheritable.choices).to eq(%w[green yellow])
    end
  end

  # Issue #208 — the type is validated by the shared command now, so the form
  # reports an unsupported type the way the machine contract does (a required
  # field on :type) and creates nothing.
  describe 'POST /chromosomes/:id/alleles (HTML create, unsupported type)' do
    it 're-renders the form with 422 and creates nothing' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)

      expect do
        post chromosome_alleles_url(chromosome),
             params: { allele: { name: 'legs', type: 'Widget' } },
             as: :html
      end.not_to change(Allele, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('is required')
    end
  end

  # Issue #208 — the web form must still SHOW a model failure. The command now
  # owns the rules, so the message reaches the form through the record (and its
  # inheritable) rather than through controller-side error copying: this is the
  # path a controller-only refactor silently breaks.
  describe 'PATCH /chromosomes/:id/alleles/:id (HTML update, model failure)' do
    it 're-renders the option field with the choice-list rule inline' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_option(name: 'color', choices: %w[red blue])).last

      patch chromosome_allele_url(chromosome, allele),
            params: { allele: { choices: '' } },
            as: :html

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('field-error')
      expect(response.body).to include('must not be empty')
      expect(allele.reload.inheritable.choices).to eq(%w[red blue])
    end

    it 're-renders the bounds rule for a reversed numeric edit' do
      chromosome = FactoryBot.create(:chromosome, organization: organization)
      allele = (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 2, maximum: 4)).last

      patch chromosome_allele_url(chromosome, allele),
            params: { allele: { minimum: 5, maximum: 3 } },
            as: :html

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('less than or equal')
      expect(allele.reload.inheritable.minimum).to eq(2)
    end
  end
end
