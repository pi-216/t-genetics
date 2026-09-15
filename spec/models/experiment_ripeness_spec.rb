# frozen_string_literal: true

require 'rails_helper'

# QA-2026-09-14 MEDIUM-3 (issue #168) — evolution must not fire while the
# current generation still contains organisms the customer never saw. The
# ripeness math used to be "% of generation reported": with population 4 and
# the default thresholds (feedback 0.75 / min 2), three reported outcomes
# made the experiment ripe while the fourth organism had never been suggested
# (no PerformanceLog — a log exists only after RequestSuggestion runs).
# Evolving then silently dropped the unseen organism from the loop. The gate:
# ripeness requires EVERY organism of the current generation to have been
# suggested at least once. This spec pins the "population N, reports < N"
# boundary from the issue's acceptance criteria.
RSpec.describe Experiment do
  describe '#ripe_for_evolution?' do
    let(:chromosome) { FactoryBot.create(:chromosome_with_alleles) }
    let(:external_entity) { FactoryBot.create(:chromosome, name: 'Ripeness External Entity') }
    let(:population_size) { 4 }
    let(:experiment) do
      FactoryBot.create(:experiment,
                        chromosome: chromosome,
                        external_entity: external_entity,
                        configuration: { 'population_size' => population_size },
                        feedback_percentage_threshold: 0.75,
                        min_organisms_with_feedback: 2,
                        suggestion_count_threshold_multiplier: 0,
                        status: 'running')
    end
    let!(:generation) { FactoryBot.create(:generation, chromosome: chromosome, iteration: 0) }
    let!(:organisms) { FactoryBot.create_list(:organism, population_size, generation: generation) }

    before { experiment.update!(current_generation: generation) }

    # Registers a suggested-but-unreported log for a single organism (as
    # RequestSuggestion would, minus the drawing logic).
    def suggest(organism)
      PerformanceLog.create!(experiment: experiment, organism: organism, suggested_at: Time.current)
    end

    # Registers a reported outcome for one organism directly at the data layer
    # (a suggestion log + a fitness value, as RecordOutcome leaves it).
    def report_fitness(organism, fitness = 0.81)
      log = PerformanceLog.create!(experiment: experiment, organism: organism, suggested_at: Time.current)
      log.update!(fitness_input_value: fitness, outcome_recorded_at: Time.current)
    end

    context 'when reports < population but one organism was never suggested' do
      before do
        organisms.first(3).each { |organism| report_fitness(organism) }
        # organisms.last has NO PerformanceLog — never put before the customer.
      end

      it 'is NOT ripe at 3/4 reported (the issue boundary: reports < population)' do
        expect(experiment.ripe_for_evolution?).to be false
      end

      it 'becomes ripe once the remaining organism has been suggested' do
        suggest(organisms.last)
        expect(experiment.ripe_for_evolution?).to be true
      end
    end

    context 'when the whole generation has been suggested' do
      before do
        organisms.each { |organism| suggest(organism) }
      end

      it 'is ripe at 3/4 reported with the default thresholds' do
        organisms.first(3).each do |organism|
          PerformanceLog.where(experiment_id: experiment.id, organism_id: organism.id)
                        .first
                        .update!(fitness_input_value: 0.81, outcome_recorded_at: Time.current)
        end
        expect(experiment.ripe_for_evolution?).to be true
      end

      it 'is not ripe while fewer than the threshold fraction have reported' do
        organisms.first(2).each do |organism|
          PerformanceLog.where(experiment_id: experiment.id, organism_id: organism.id)
                        .first
                        .update!(fitness_input_value: 0.81, outcome_recorded_at: Time.current)
        end
        expect(experiment.ripe_for_evolution?).to be false
      end
    end

    context 'when not every organism has been suggested (regression for an empty generation gate)' do
      it 'is not ripe with zero suggestions and zero reports' do
        expect(experiment.ripe_for_evolution?).to be false
      end
    end
  end
end
