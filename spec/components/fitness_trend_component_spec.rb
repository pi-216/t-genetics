# frozen_string_literal: true

require 'rails_helper'

# PRD-0004 DEV-0006 (issue #82) — the per-generation average fitness trend.
# The component reads the recorded (customer-reported) fitness from the
# PerformanceLog — the same record the suggestion card reads (issue #170) —
# and renders ONE point per generation with recorded fitness, joined by a
# self-hosted inline SVG polyline. No charting gem, no external CDN.
RSpec.describe FitnessTrendComponent, type: :component do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: org) }
  let!(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                     name: 'Donation amounts',
                                     experiment_configuration: { population_size: 10 })
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  def points_of(rendered)
    rendered.css('.fitness-trend-point').map { |p| [p['data-generation'], p['data-fitness']] }
  end

  # A reported organism: one PerformanceLog with the customer-reported number
  # (organism.fitness stays nil — the trend must not depend on the
  # evolution-time cache, issue #170).
  def reported(generation:, fitness:)
    organism = FactoryBot.create(:organism, generation: generation, fitness: nil)
    PerformanceLog.create!(experiment:, organism: organism, suggested_at: Time.current,
                           fitness_input_value: fitness)
    organism
  end

  # Issue #170 — a customer-reported fitness is the single source of truth
  # for display (the same record the suggestion card reads). The trend must
  # render a point for a reported organism even before evolution writes
  # organism.fitness — report → trend visibility without waiting for the
  # next evolution.
  it 'renders a point from the reported log before evaluation writes organism fitness' do
    reported(generation: experiment.current_generation, fitness: 0.77)

    rendered = render_inline(described_class.new(experiment: experiment))

    expect(points_of(rendered)).to eq([['0', '0.77']])
  end

  it 'renders one point per generation with a recorded (averaged) fitness' do
    reported(generation: experiment.current_generation, fitness: 1.0)
    reported(generation: experiment.current_generation, fitness: 0.5)
    # A generation with an organism but no report carries no point.
    FactoryBot.create(:generation, chromosome:, iteration: 1)

    rendered = render_inline(described_class.new(experiment: experiment))

    expect(points_of(rendered)).to eq([['0', '0.75']])
    expect(rendered.css('polyline.fitness-trend-line')).not_to be_empty
  end

  it 'joins generations in iteration order with one polyline point each' do
    gen1 = FactoryBot.create(:generation, chromosome:, iteration: 1)
    gen2 = FactoryBot.create(:generation, chromosome:, iteration: 2)
    reported(generation: experiment.current_generation, fitness: 0.5)
    reported(generation: gen1, fitness: 0.9)
    reported(generation: gen2, fitness: 0.7)

    rendered = render_inline(described_class.new(experiment: experiment))

    expect(points_of(rendered)).to eq([['0', '0.5'], ['1', '0.9'], ['2', '0.7']])
    expect(rendered.css('polyline.fitness-trend-line').first['points'].split.size).to eq(3)
  end

  it 'renders an explicit empty state when no fitness is reported yet' do
    rendered = render_inline(described_class.new(experiment: experiment))

    expect(rendered.css('.fitness-trend-empty')).not_to be_empty
    expect(rendered.css('.fitness-trend-point')).to be_empty
  end
end
