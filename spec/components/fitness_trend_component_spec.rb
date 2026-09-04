# frozen_string_literal: true

require 'rails_helper'

# PRD-0004 DEV-0006 (issue #82) — the per-generation average fitness trend.
# The component reads the recorded fitness averages the engine writes on
# organisms at evaluation time (the same values the generation history page
# shows) and renders ONE point per generation with recorded fitness, joined
# by a self-hosted inline SVG polyline. No charting gem, no external CDN.
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

  it 'renders one point per generation with a recorded (averaged) fitness' do
    FactoryBot.create(:organism, generation: experiment.current_generation, fitness: 1.0)
    FactoryBot.create(:organism, generation: experiment.current_generation, fitness: 0.5)
    FactoryBot.create(:organism, generation: FactoryBot.create(:generation, chromosome:, iteration: 1), fitness: nil)

    rendered = render_inline(described_class.new(experiment: experiment))

    expect(points_of(rendered)).to eq([['0', '0.75']])
    expect(rendered.css('polyline.fitness-trend-line')).not_to be_empty
  end

  it 'joins generations in iteration order with one polyline point each' do
    gen1 = FactoryBot.create(:generation, chromosome:, iteration: 1)
    gen2 = FactoryBot.create(:generation, chromosome:, iteration: 2)
    FactoryBot.create(:organism, generation: experiment.current_generation, fitness: 0.5)
    FactoryBot.create(:organism, generation: gen1, fitness: 0.9)
    FactoryBot.create(:organism, generation: gen2, fitness: 0.7)

    rendered = render_inline(described_class.new(experiment: experiment))

    expect(points_of(rendered)).to eq([['0', '0.5'], ['1', '0.9'], ['2', '0.7']])
    expect(rendered.css('polyline.fitness-trend-line').first['points'].split.size).to eq(3)
  end

  it 'renders an explicit empty state when no fitness is recorded yet' do
    rendered = render_inline(described_class.new(experiment: experiment))

    expect(rendered.css('.fitness-trend-empty')).not_to be_empty
    expect(rendered.css('.fitness-trend-point')).to be_empty
  end
end
