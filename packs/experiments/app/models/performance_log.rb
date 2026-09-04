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
end
