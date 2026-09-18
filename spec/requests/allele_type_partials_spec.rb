# frozen_string_literal: true

require 'rails_helper'

# Issue #206 — the allele form and the chromosome show-page preview used to
# branch inline on allele.type. Each constraint-field group and each preview
# detail now lives in its own partial, dispatched through AllelesHelper's
# type → partial maps, so the shared views only loop and render. These
# examples pin both halves of the contract: the shared views carry no type
# branching, and the rendered DOM keeps one field group per constraint family
# with the pinned ids/targets and the per-type preview detail.
module AlleleTypeBranching
  SHARED_VIEWS = [
    'app/views/chromosomes/alleles/_form.html.erb',
    'app/views/chromosomes/show.html.erb'
  ].freeze

  # A conditional on a single allele's type against a literal type name is
  # exactly what this ticket moved out of the shared views; the type's markup
  # lives in its own partial now. The type select's per-option state
  # (`allele.type == type` inside the type-name loop) is not type-specific
  # markup and stays in the shared view.
  PATTERNS = [
    /allele\.type\s*(?:==|!=|=~)\s*'/,
    /\.include\?\(allele\.type\)/,
    /case\s+allele\.type/,
    /numeric_type\?/
  ].freeze

  def type_branching_lines(path)
    Rails.root.join(path).read.lines.each_with_index.filter_map do |line, index|
      "#{path}:#{index + 1}: #{line.strip}" if PATTERNS.any? { |pattern| pattern.match?(line) }
    end
  end
end

RSpec.describe 'Allele type-specific partials (issue #206)' do
  include AlleleTypeBranching

  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let(:chromosome) { FactoryBot.create(:chromosome, name: 'Mixed genome', organization:) }

  before { sign_in_as(organization:) }

  describe 'the shared allele views' do
    it 'carry no inline type branching' do
      offences = AlleleTypeBranching::SHARED_VIEWS.flat_map { |path| type_branching_lines(path) }

      expect(offences).to be_empty,
                          "type-specific markup belongs in its own partial: #{offences.inspect}"
    end

    it 'render the type-specific markup through the helper maps' do
      form, show = AlleleTypeBranching::SHARED_VIEWS.map { |path| Rails.root.join(path).read }

      expect(form).to include('allele_field_groups')
      expect(show).to include('allele_preview_partial')
    end
  end

  describe 'GET /chromosomes/:id/alleles/new' do
    # Float and Integer share the numeric field group; rendering a partial per
    # numeric type would duplicate the pinned `allele_minimum`/`allele_maximum`
    # ids and the Stimulus target, and the type-walk scenario reads both.
    it 'renders one field group per constraint family with the pinned ids' do
      get new_chromosome_allele_url(chromosome)
      doc = Nokogiri::HTML(response.body)

      expect(doc.css('[data-allele-type-fields-target="numeric"]').size).to eq(1)
      expect(doc.css('[data-allele-type-fields-target="option"]').size).to eq(1)
      expect(doc.css('#allele_minimum').size).to eq(1)
      expect(doc.css('#allele_choices').size).to eq(1)
    end

    it 'activates the numeric group for the default (Float) allele' do
      get new_chromosome_allele_url(chromosome)

      expect(field_group_hidden(response.body)).to eq('numeric' => false, 'option' => true)
    end
  end

  describe 'GET /chromosomes/:id/alleles/:id/edit' do
    {
      'Float' => { 'numeric' => false, 'option' => true },
      'Integer' => { 'numeric' => false, 'option' => true },
      'Boolean' => { 'numeric' => true, 'option' => true },
      'Option' => { 'numeric' => true, 'option' => false }
    }.each do |type, hidden|
      it "activates only the #{type} allele's field group" do
        get edit_chromosome_allele_url(chromosome, build_allele(type)), as: :html

        expect(field_group_hidden(response.body)).to eq(hidden)
      end
    end
  end

  describe 'GET /chromosomes/:id (allele list preview)' do
    it 'renders the bounds detail for a numeric allele' do
      build_allele('Integer')

      expect(preview_row('.allele-bounds')).to eq('(1…4)')
    end

    it 'renders the choices detail for an option allele' do
      build_allele('Option')

      expect(preview_row('.allele-choices')).to eq('[red, blue]')
    end

    it 'renders no constraint detail for a boolean allele' do
      build_allele('Boolean')
      get chromosome_url(chromosome)

      row = Nokogiri::HTML(response.body).at_css('.allele-preview-item')
      expect(row.css('.allele-bounds, .allele-choices')).to be_empty
    end
  end

  def build_allele(type)
    allele = case type
             when 'Float' then Allele.new_with_float(name: 'weight', minimum: 0, maximum: 10)
             when 'Integer' then Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 4)
             when 'Boolean' then Allele.new_with_boolean(name: 'wings')
             when 'Option' then Allele.new_with_option(name: 'color', choices: %w[red blue])
             end
    chromosome.alleles << allele
    allele
  end

  # The hidden attribute per field group in the rendered form.
  def field_group_hidden(body)
    Nokogiri::HTML(body).css('[data-allele-type-fields-target]').to_h do |group|
      [group['data-allele-type-fields-target'], group.key?('hidden')]
    end
  end

  def preview_row(selector)
    get chromosome_url(chromosome)
    Nokogiri::HTML(response.body).at_css('.allele-preview-item').at_css(selector).text.strip
  end
end
