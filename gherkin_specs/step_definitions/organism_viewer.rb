# frozen_string_literal: true

# Step definitions for PRD-0004 DEV-0005 (issue #81) — a member opens an
# organism from the generation browser and sees each value rendered by its
# allele type. The Given builds the real domain state through the same Setup
# command the UI create flow runs (experiment_named lives in
# experiment_workspace.rb — shared step file, same load path): a chromosome
# with mixed allele types (float/int/bool), an experiment whose birthed
# generation contains organisms, and typed value data materialized through
# the engine's own mutation path (Valuable#mutate!) — exactly what an
# evolved generation's values look like.
#
# NOTE: the chromosome must be reloaded after adding alleles — Chromosome's
# after_initialize hook caches the (then empty) allele collection on the
# instance, and Organisms::Create would otherwise birth organisms whose
# values came from a stale empty collection. Reload resets the cache.

NUMERIC_ALLELE_TYPES = %w[Float Integer].freeze

Given(/^the generation browser shows an organism$/) do
  organization = Identity::Organization.find_or_create_by!(name: 'Loop Labs')
  chromosome = organization.chromosomes.find_or_create_by!(name: 'Alpha-chrom')

  unless chromosome.alleles.exists?
    float_allele = Allele.new_with_float(name: 'size', minimum: 0.0, maximum: 1.0)
    float_allele.chromosome = chromosome
    float_allele.save!
    integer_allele = Allele.new_with_integer(name: 'count', minimum: 1, maximum: 10)
    integer_allele.chromosome = chromosome
    integer_allele.save!
    boolean_allele = Allele.new_with_boolean(name: 'enabled')
    boolean_allele.chromosome = chromosome
    boolean_allele.save!
    option_allele = Allele.new_with_option(name: 'color', choices: %w[red blue])
    option_allele.chromosome = chromosome
    option_allele.save!
  end
  chromosome.reload

  experiment = experiment_named('Donation amounts')
  organisms = experiment.current_generation.organisms.to_a
  expect(organisms).not_to be_empty
  @open_organism = organisms.first
  @open_organism.values.to_a.each(&:mutate!)

  visit history_experiment_path(experiment)
  expect(page).to have_content("Organism ##{@open_organism.id}")
end

When(/^I open the organism$/) do
  organism = @open_organism or raise 'the generation browser Given did not set @open_organism'
  click_link "Organism ##{organism.id}"
end

Then(/^I see each value rendered by its allele type$/) do
  organism = @open_organism
  values = organism.values.includes(:allele).sort_by { |v| v.allele.name }
  expect(values).not_to be_empty
  rows_by_allele = page.all('.value-row').index_by { |row| row['data-allele'] }

  values.each do |value|
    type = value.allele.type
    row = rows_by_allele[value.allele.name]
    expect(row).not_to be_nil, "expected a value row for allele #{value.allele.name}"
    expect(row['data-type']).to eq(type.downcase)
    expect(row[:class]).to include("value-#{type.downcase}")

    if type == 'Boolean'
      expect(%w[true false]).to include(row.find('.value-badge').text)
    elsif NUMERIC_ALLELE_TYPES.include?(type)
      expect(row).to have_css('.value-bounds', text: /bounds/)
    else
      expect(row).to have_css('.value-data')
    end
  end
end
