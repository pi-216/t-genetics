# frozen_string_literal: true

require 'rails_helper'

# Issue #206 — each allele type's constraint fields and preview detail render
# from their own partial. These examples render the partials in isolation so
# every type's markup has exactly one home, with the ids the machine contract
# (`allele[minimum]`, `allele[choices]`) and the BDD selectors pin.
RSpec.describe 'chromosomes/alleles — type-specific partials' do
  it 'renders the numeric field group with the pinned ids and target' do
    render_numeric(Alleles::Float.new, active: true)

    expect(rendered).to include('data-allele-type-fields-target="numeric"')
    expect(rendered).to include('id="allele_minimum"', 'id="allele_maximum"')
  end

  # The numeric group renders for every form (the Stimulus toggle reveals it
  # client-side), so its value lookups must never touch a non-numeric
  # inheritable — an Option allele has no minimum.
  it 'renders the numeric field group hidden and empty for a non-numeric allele' do
    render_numeric(Alleles::Option.new(choices: %w[red]), active: false)
    doc = Nokogiri::HTML(rendered)

    expect(doc.at_css('[data-allele-type-fields-target="numeric"]').key?('hidden')).to be(true)
    expect(doc.at_css('#allele_minimum')['value']).to eq('')
  end

  it 'renders the option field group with the comma-joined choices' do
    render partial: 'chromosomes/alleles/option_fields',
           locals: { allele: Allele.new(inheritable: Alleles::Option.new(choices: %w[red blue])),
                     active: true }

    expect(rendered).to include('data-allele-type-fields-target="option"')
    expect(Nokogiri::HTML(rendered).at_css('#allele_choices')['value']).to eq('red, blue')
  end

  it 'renders the boolean field group with no constraint fields' do
    render partial: 'chromosomes/alleles/boolean_fields',
           locals: { allele: Allele.new(inheritable: Alleles::Boolean.new), active: true }

    expect(Nokogiri::HTML(rendered).css('input, select')).to be_empty
  end

  it 'renders the numeric preview with the allele bounds' do
    render partial: 'chromosomes/alleles/numeric_preview',
           locals: { allele: Allele.new(inheritable: Alleles::Integer.new(minimum: 1, maximum: 4)) }

    expect(rendered).to include('allele-bounds')
    expect(rendered).to include('(1…4)')
  end

  it 'renders the option preview with the allele choices' do
    render partial: 'chromosomes/alleles/option_preview',
           locals: { allele: Allele.new(inheritable: Alleles::Option.new(choices: %w[red blue])) }

    expect(rendered).to include('allele-choices')
    expect(rendered).to include('[red, blue]')
  end

  it 'renders the boolean preview with no constraint detail' do
    render partial: 'chromosomes/alleles/boolean_preview',
           locals: { allele: Allele.new(inheritable: Alleles::Boolean.new) }

    expect(rendered).not_to include('allele-bounds', 'allele-choices')
  end

  def render_numeric(inheritable, active:)
    render partial: 'chromosomes/alleles/numeric_fields',
           locals: { allele: Allele.new(inheritable: inheritable), active: }
  end
end
