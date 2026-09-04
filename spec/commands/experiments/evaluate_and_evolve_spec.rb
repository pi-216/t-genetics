# frozen_string_literal: true

require 'rails_helper'

# PRD-0003 DEV-0006 (issue #73) — evolution does not double-fire. The
# double-fire hazard: two loop actions (double-click, web + machine API
# racing, or a client retry) can BOTH pass the ripe check before either
# commits, and each then runs this command against the same pre-evolution
# state — breeding TWO sibling generations from one parent. The command must
# serialize evolution on the experiment row and adopt the concurrent winner
# instead of breeding a duplicate (PRD-0003: "Evolution must be idempotent —
# a double-fire must not create two generations").
RSpec.describe Experiments::EvaluateAndEvolve do
  let(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom') }
  let(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                     name: 'Donation amounts',
                                     experiment_configuration: { population_size: 4 })
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  # Drives the real loop commands (suggest → report) until the experiment's
  # own ripe_for_evolution? turns true — same driver the BDD Given uses.
  def make_ripe
    experiment.start!
    until experiment.reload.ripe_for_evolution?
      suggestion = Experiments::RequestSuggestion.call(experiment:)
      raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

      outcome = Experiments::RecordOutcome.call(performance_log: suggestion.performance_log,
                                                fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end
  end

  describe 'when two evolutions race on the same ripe state' do
    before { make_ripe }

    it 'breeds exactly one offspring generation (the double-fire guard)' do
      # The second caller observed the SAME pre-evolution state (its view
      # caches generation 0) before the first evolution commits.
      racing_view = Experiment.find(experiment.id)
      racing_view.current_generation # cache the pre-evolution generation

      first = described_class.call(experiment:)
      expect(first).to be_success

      second = described_class.call(experiment: racing_view)
      expect(second).to be_success

      # Setup births generation 0; one evolution creates iteration 1. A
      # double-fire leaves TWO sibling iteration-1 generations.
      expect(Generation.where(chromosome: experiment.chromosome).count).to eq(2)
      expect(Generation.where(chromosome: experiment.chromosome, iteration: 1).count).to eq(1)
      expect(experiment.reload.current_generation.iteration).to eq(1)
    end
  end
end
