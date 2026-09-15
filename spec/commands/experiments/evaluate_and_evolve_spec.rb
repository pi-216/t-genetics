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

  # QA-2026-09-14 CRITICAL-2 (issue #167) + MEDIUM-3 (issue #168) — an
  # organism without a reported fitness must not receive a fabricated fitness
  # at evolution. Post-#168 ripeness requires EVERY organism of the current
  # generation to have been SUGGESTED before evolution can fire, so the
  # unreported state that survives to evolution is "suggested but not yet
  # reported" (the payment-form case: the customer saw it, never sent the
  # number). Evolving must leave its fitness NULL — the with_fitness scope
  # excludes it from the evolution average AND from breeding selection —
  # never a written 0.0, and the generation must not contain an organism
  # that was never suggested at all.
  describe 'when a generation contains an organism with no reported fitness' do
    let(:parent_generation) { Generation.where(chromosome: experiment.chromosome, iteration: 0).first! }

    before do
      experiment.start!
      # The whole generation has been suggested (issue #168's gate): each
      # organism carries a suggestion log, exactly as RequestSuggestion
      # leaves one.
      parent_generation.organisms.each do |org|
        PerformanceLog.create!(experiment: experiment, organism: org, suggested_at: Time.current)
      end
      # Only three of four organisms have a reported outcome — the fourth is
      # suggested-but-unreported (customer saw it, hasn't reported yet).
      PerformanceLog.where(experiment_id: experiment.id).order(:id).first(3).each do |log|
        outcome = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: 0.81)
        raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
      end
    end

    def untested_organism
      parent_generation.organisms.find do |organism|
        PerformanceLog.where(experiment_id: experiment.id, organism_id: organism.id)
                      .where.not(fitness_input_value: nil).none?
      end
    end

    it 'leaves exactly one organism suggested-but-unreported before evolution (scenario shape)' do
      expect(parent_generation.organisms.count).to eq(4)
      expect(untested_organism).to be_present
      # Every organism has a suggestion log — the never-suggested state that
      # tripped MEDIUM-3 is impossible here.
      expect(PerformanceLog.where(experiment_id: experiment.id)
                           .distinct.pluck(:organism_id).size).to eq(4)
      expect(experiment.ripe_for_evolution?).to be true
    end

    it 'does not write fitness 0.0 for an organism nobody reported' do
      organism = untested_organism
      expect(organism.fitness).to be_nil

      expect(described_class.call(experiment:)).to be_success

      expect(organism.reload.fitness).to be_nil
      expect(Generation.where(chromosome: experiment.chromosome, iteration: 1).count).to eq(1)
    end

    it 'excludes the unreported organism from the evolution average and breeding pool' do
      expect(described_class.call(experiment:)).to be_success

      average = Generations::Fitness.call(generation: parent_generation).average_fitness
      expect(average).to eq(0.81)

      expect(parent_generation.organisms.with_fitness.pluck(:id)).not_to include(untested_organism.id)
    end
  end

  # QA-2026-09-14 MEDIUM-3 (issue #168) — the command boundary must fail
  # closed when a caller invokes EvaluateAndEvolve directly on a generation
  # that still contains an organism never suggested to the customer (the
  # ripe_for_evolution? gate only protects the auto path through
  # RequestSuggestion; this proves the rule holds for direct invocations).
  describe 'when the current generation contains an organism that was never suggested' do
    before do
      experiment.start!
      # Report three of four organisms but never SUGGEST the fourth — no log
      # at all, never put before the customer.
      parent_generation = Generation.where(chromosome: experiment.chromosome, iteration: 0).first!
      parent_generation.organisms.first(3).each do |org|
        PerformanceLog.create!(experiment: experiment, organism: org, suggested_at: Time.current)
                      .update!(fitness_input_value: 0.81, outcome_recorded_at: Time.current)
      end
    end

    it 'refuses to evolve and breeds nothing' do
      generations_before = Generation.where(chromosome: experiment.chromosome).count

      result = described_class.call(experiment:)

      expect(result).not_to be_success
      expect(result.errors.full_messages.join).to match(/never suggested/)
      expect(Generation.where(chromosome: experiment.chromosome).count).to eq(generations_before)
    end
  end
end
