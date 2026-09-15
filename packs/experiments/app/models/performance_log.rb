# frozen_string_literal: true

class PerformanceLog < ApplicationRecord
  belongs_to :experiment
  belongs_to :organism

  validates :experiment, presence: true
  validates :organism, presence: true
  validates :suggested_at, presence: true

  # Machine-API representation (PRD-0005): the suggestion/outcome record a
  # client drives the loop with — which organism was suggested, when, and the
  # single customer-reported fitness number once the machine reports back.
  def to_h
    {
      id: id,
      experiment_id: experiment_id,
      organism_id: organism_id,
      suggested_at: suggested_at,
      fitness_input_value: fitness_input_value,
      outcome_metrics: outcome_metrics,
      outcome_recorded_at: outcome_recorded_at
    }
  end

  # Issue #170 — the recorded (customer-reported) fitness per organism: the
  # average of the organism's reported outcome values for this experiment.
  # This is the SAME aggregation EvaluateAndEvolve writes into
  # organism.fitness at evaluation time, made directly readable so a report
  # is visible immediately (the suggestion card, generation history, fitness
  # trend, and organism viewer all read this single source instead of the
  # evolution-time cache). Returns { organism_id => Float } for the
  # experiment's chromosome organisms.
  def self.recorded_fitness_by_organism(experiment:)
    chromosome = experiment.chromosome
    organism_ids = Organism.where(generation: Generation.where(chromosome: chromosome)).ids
    where(experiment_id: experiment.id, organism_id: organism_ids)
      .where.not(fitness_input_value: nil)
      .group(:organism_id)
      .average(:fitness_input_value)
  end

  # Issue #170 — the recorded (customer-reported) fitness for ONE organism
  # across every experiment that suggested it (the organism viewer is
  # chromosome-scoped, so no experiment context exists there): the average of
  # its reported outcome values, nil when nothing is reported yet. Same
  # aggregation definition as #recorded_fitness_by_organism and
  # EvaluateAndEvolve — display never waits on the evolution-time cache.
  def self.recorded_fitness_for(organism)
    where(organism_id: organism.id)
      .where.not(fitness_input_value: nil)
      .average(:fitness_input_value)
  end
end
