# frozen_string_literal: true

require 'rails_helper'

# PRD-0005 Q4 (issue #131) — Experiments::CurrentSuggestion is the read-only
# counterpart to RequestSuggestion: it returns the experiment's current
# PENDING suggestion (most recent unreported PerformanceLog whose organism is
# in the CURRENT generation) and NEVER creates a PerformanceLog. Stability
# contract: a re-read returns the same suggestion until an outcome is recorded
# (the log gains fitness_input_value and drops out of the pending set) or the
# generation evolves (the organism's generation is no longer current).
RSpec.describe Experiments::CurrentSuggestion do
  let(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom') }
  let(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                     name: 'Donation amounts',
                                     experiment_configuration: { population_size: 4 })
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  def request_suggestion
    result = Experiments::RequestSuggestion.call(experiment:)
    raise "RequestSuggestion failed: #{result.errors.inspect}" unless result.success?

    result.performance_log
  end

  # Drives the loop until the experiment is ripe, then evolves it directly —
  # the current generation advances by one without any new suggestion log.
  def evolve_to_next_generation
    until experiment.reload.ripe_for_evolution?
      log = request_suggestion
      outcome = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end

    evolve = Experiments::EvaluateAndEvolve.call(experiment: experiment.reload)
    raise "EvaluateAndEvolve failed: #{evolve.errors.inspect}" unless evolve.success?
  end

  describe 'when a suggestion is pending' do
    let!(:pending_log) { request_suggestion }

    it 'returns the most recent pending performance log' do
      result = described_class.call(experiment: experiment.reload)

      expect(result).to be_success
      expect(result.performance_log).to eq(pending_log)
    end

    it 'returns the MOST RECENT log when several are pending (order pinned)' do
      older_log = request_suggestion
      newest_log = request_suggestion
      expect(newest_log.id).to be > older_log.id

      result = described_class.call(experiment: experiment.reload)

      expect(result.performance_log).to eq(newest_log)
    end

    it 'never creates a PerformanceLog (read-only)' do
      expect { described_class.call(experiment: experiment.reload) }
        .not_to change(PerformanceLog, :count)
    end

    it 'is stable across re-reads' do
      first = described_class.call(experiment: experiment.reload)

      expect(described_class.call(experiment: experiment.reload).performance_log)
        .to eq(first.performance_log)
    end
  end

  describe 'reporting an outcome clears the pending suggestion' do
    before do
      log = request_suggestion
      outcome = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end

    it 'returns nil when the only pending log gains a fitness value' do
      result = described_class.call(experiment: experiment.reload)

      expect(result).to be_success
      expect(result.performance_log).to be_nil
    end
  end

  describe 'when nothing has ever been suggested' do
    it 'returns nil (explicit empty, never silent)' do
      result = described_class.call(experiment: experiment.reload)

      expect(result).to be_success
      expect(result.performance_log).to be_nil
    end
  end

  describe 'generation evolution invalidates the previous suggestion' do
    it 'does not return a pending log whose organism is in a superseded generation' do
      # Create a PENDING log in generation 0 and keep it unreported. Then make
      # the experiment ripe and evolve it directly (EvaluateAndEvolve), so the
      # current generation advances to 1 while the gen-0 pending log still
      # exists. The stale pending log must NOT be returned as "current" — the
      # current-suggestion read is scoped to the CURRENT generation.
      stale_log = request_suggestion
      expect(stale_log.organism.generation).to eq(experiment.current_generation)

      evolve_to_next_generation

      expect(experiment.reload.current_generation.iteration).to eq(1)
      # The stale pending log still exists — but it is no longer current.
      expect(stale_log.reload.fitness_input_value).to be_nil
      expect(PerformanceLog.where(experiment_id: experiment.id, fitness_input_value: nil))
        .to include(stale_log)

      result = described_class.call(experiment: experiment.reload)

      expect(result).to be_success
      expect(result.performance_log).to be_nil
    end
  end

  describe 'when the experiment has no current generation' do
    it 'returns nil' do
      generationless = FactoryBot.create(:experiment, chromosome:, external_entity: chromosome)

      result = described_class.call(experiment: generationless)

      expect(result).to be_success
      expect(result.performance_log).to be_nil
    end
  end
end
