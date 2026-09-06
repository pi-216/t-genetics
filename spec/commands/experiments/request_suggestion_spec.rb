# frozen_string_literal: true

require 'rails_helper'

# PRD-0003 DEV-0005 (issue #72) — a ripe experiment evolves on the next loop
# action. RequestSuggestion is the shared loop action for the web UI and the
# machine API (PRD-0005), so the auto-evolve trigger lives in the command:
# when the experiment is ripe_for_evolution?, the command first runs
# Experiments::EvaluateAndEvolve (new generation replaces current), then
# suggests from the NEW generation. A non-ripe experiment is unaffected
# (regression guard for DEV-0003/0004).
RSpec.describe Experiments::RequestSuggestion do
  let(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom') }
  let(:experiment) do
    result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                     name: 'Donation amounts',
                                     experiment_configuration: { population_size: 4 })
    raise "Setup failed: #{result.errors.inspect}" unless result.success?

    result.experiment
  end

  # Drives the real loop commands (suggest → report) until the experiment's
  # own ripe_for_evolution? turns true, exactly like the BDD Given does.
  def make_ripe
    experiment.start! # ripeness requires a running experiment (AASM)
    until experiment.reload.ripe_for_evolution?
      suggestion = described_class.call(experiment:)
      raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

      outcome = Experiments::RecordOutcome.call(performance_log: suggestion.performance_log,
                                                fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end
  end

  describe 'when the experiment is ripe' do
    before { make_ripe }

    it 'evolves first: creates a new generation that replaces the current one' do
      previous_generation = experiment.current_generation

      result = described_class.call(experiment:)

      expect(result).to be_success
      expect(experiment.reload.current_generation).not_to eq(previous_generation)
      expect(experiment.current_generation.iteration).to eq(previous_generation.iteration + 1)
    end

    it 'records the suggestion against an organism of the NEW generation' do
      result = described_class.call(experiment:)

      expect(result.success?).to be true
      expect(result.organism.generation).to eq(experiment.reload.current_generation)
      expect(result.performance_log.organism.generation.iteration).to eq(1)
    end

    it 'fails the suggestion when evolution fails instead of silently suggesting stale organisms' do
      failed_evolution = double(success?: false, errors: { base: ['evolution blew up'] })
      allow(Experiments::EvaluateAndEvolve).to receive(:call).and_return(failed_evolution)
      logs_before = PerformanceLog.where(experiment_id: experiment.id).count

      result = described_class.call(experiment:)

      expect(result).not_to be_success
      expect(result.errors.full_messages.join).to include('evolution blew up')
      # No NEW suggestion log from the failed call (the logs from make_ripe stay).
      expect(PerformanceLog.where(experiment_id: experiment.id).count).to eq(logs_before)
      expect(experiment.reload.current_generation.iteration).to eq(0)
    end
  end

  describe 'when the experiment is not ripe' do
    it 'suggests from the current generation without evolving' do
      expect { described_class.call(experiment:) }
        .not_to(change { experiment.reload.current_generation })

      expect(Generation.where(chromosome: experiment.chromosome).count).to eq(1)
    end
  end

  describe 'double-fire protection (PRD-0003 DEV-0006, issue #73)' do
    before { make_ripe }

    it 'does not create a second generation when a racing loop action fires on the same ripe state' do
      # A second loop action (double-click, web+API race, retry) observed the
      # SAME pre-evolution ripe state: its experiment view caches generation 0
      # before the first action's evolution commits.
      racing_view = Experiment.find(experiment.id)
      racing_view.current_generation

      first = described_class.call(experiment:)
      expect(first).to be_success

      second = described_class.call(experiment: racing_view)
      expect(second).to be_success

      # Setup births generation 0; exactly ONE offspring (iteration 1) may
      # exist — a double-fire leaves two siblings.
      expect(Generation.where(chromosome: experiment.chromosome).count).to eq(2)
      expect(Generation.where(chromosome: experiment.chromosome, iteration: 1).count).to eq(1)
    end
  end

  # Founder ruling 2026-09-04 (issue #130, "Suggestion semantics" in
  # docs/design-sprint/ph2/ux-concept.md): a suggestion is a UNIFORM RANDOM
  # draw from the current generation's UNTESTED pool — organisms without a
  # reported fitness for this experiment (a PerformanceLog with a
  # fitness_input_value). A reported organism is never suggested again while
  # the generation is current; a suggested-but-unreported organism stays in
  # the pool (its pending log carries no fitness value); exploit mode
  # (proportional sampling of known-good organisms) is paid-tier and
  # deliberately absent.
  #
  # Thresholds are pinned far out of reach (1.0 / 99 / 0) so the repeated-draw
  # examples never trip ripeness — the pool stays stable for the whole run.
  describe 'suggestion pool — untested organisms only, uniform random draw (issue #130)' do
    let(:experiment) do
      result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                       name: 'Donation amounts',
                                       experiment_configuration: { population_size: 4 })
      raise "Setup failed: #{result.errors.inspect}" unless result.success?

      result.experiment.tap do |exp|
        exp.update!(feedback_percentage_threshold: 1.0,
                    min_organisms_with_feedback: 99,
                    suggestion_count_threshold_multiplier: 0)
        exp.start!
      end
    end

    let(:organisms) { experiment.current_generation.organisms.to_a }

    # Records a reported fitness for one organism through the real commands
    # (the suggestion log + RecordOutcome are the only fitness inputs).
    def report_fitness_for(organism, fitness = 0.81)
      log = PerformanceLog.create!(experiment:, organism:, suggested_at: Time.current)
      outcome = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: fitness)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end

    it 'draws uniformly at random: every untested organism is reachable over repeated draws' do
      drawn_ids = Array.new(100) { described_class.call(experiment:).organism.id }.uniq

      expect(drawn_ids).to match_array(organisms.map(&:id))
    end

    it 'is non-deterministic: repeated draws from a multi-organism untested pool are not all identical' do
      drawn_ids = Array.new(20) { described_class.call(experiment:).organism.id }

      expect(drawn_ids.uniq.size).to be > 1
    end

    it 'never suggests an organism that already has a reported fitness for this experiment' do
      reported = organisms.first
      report_fitness_for(reported)

      drawn = Array.new(20) { described_class.call(experiment:).organism }

      expect(drawn).not_to include(reported)
    end

    it 'keeps a suggested-but-unreported organism in the pool (pending log carries no fitness)' do
      first_draw = described_class.call(experiment:).organism

      later_drawn_ids = Array.new(40) { described_class.call(experiment:).organism.id }

      expect(later_drawn_ids).to include(first_draw.id)
    end

    it 'refuses to suggest when every organism has a reported fitness (never a reported organism)' do
      organisms.each { |organism| report_fitness_for(organism) }
      logs_before = PerformanceLog.where(experiment_id: experiment.id).count

      result = described_class.call(experiment:)

      expect(result).not_to be_success
      expect(result.errors.full_messages.join).to match(/reported fitness/)
      expect(PerformanceLog.where(experiment_id: experiment.id).count).to eq(logs_before)
    end

    it 'still fails with the explicit empty-state error when the generation has no organisms' do
      experiment.current_generation.organisms.destroy_all
      # A fresh view so no cached organism collection masks the empty state.
      fresh = Experiment.find(experiment.id)

      result = described_class.call(experiment: fresh)

      expect(result).not_to be_success
      expect(result.errors.full_messages.join).to match(/current generation has no organisms/)
    end
  end
end
