class Experiment < ApplicationRecord
  include AASM

  belongs_to :chromosome
  belongs_to :current_generation, class_name: 'Generation', foreign_key: 'current_generation_id', optional: true

  validates :chromosome_id, presence: true
  validates :external_entity_id, presence: true
  validates :external_entity_type, presence: true
  # AASM handles status validation based on defined states

  aasm :status, column: :status do # Explicitly mention column name, though it's default
    state :pending, initial: true
    state :running
    state :completed
    state :failed

    event :start do
      transitions from: :pending, to: :running
    end

    event :complete do
      transitions from: :running, to: :completed
    end

    event :fail do
      transitions from: :running, to: :failed
    end
  end

  validates :feedback_percentage_threshold, presence: true, numericality: { greater_than_or_equal_to: 0.0, less_than_or_equal_to: 1.0 }
  validates :min_organisms_with_feedback, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :suggestion_count_threshold_multiplier, presence: true, numericality: { greater_than_or_equal_to: 0.0 }

  def ripe_for_evolution?
    return false unless running? # Auto-evolution should only occur on running experiments
    return false unless current_generation

    organisms_in_current_generation = current_generation.organisms
    return false if organisms_in_current_generation.empty?

    actual_population_size = organisms_in_current_generation.count
    # Use configured pop size for multiplier, or actual if not configured
    target_population_size_for_multiplier = configuration.fetch('population_size', actual_population_size).to_i


    # Condition A: Feedback Saturation
    logs_with_outcome_scope = PerformanceLog.where(experiment_id: id)
                                            .where(organism_id: organisms_in_current_generation.select(:id))
                                            .where.not(outcome_recorded_at: nil)
                                            .where.not(fitness_input_value: nil)

    num_organisms_with_feedback = logs_with_outcome_scope.distinct.count(:organism_id)

    if actual_population_size > 0 # Avoid division by zero
      percentage_with_feedback = num_organisms_with_feedback.to_f / actual_population_size
      return true if percentage_with_feedback >= feedback_percentage_threshold && num_organisms_with_feedback >= min_organisms_with_feedback
    end

    # Condition B: Suggestion Volume
    # Ensure suggestion_count_threshold_multiplier is positive to avoid issues with threshold calculation
    if suggestion_count_threshold_multiplier > 0 && target_population_size_for_multiplier > 0
      suggestion_volume_threshold = target_population_size_for_multiplier * suggestion_count_threshold_multiplier
      total_suggestions = PerformanceLog.where(experiment_id: id)
                                        .where(organism_id: organisms_in_current_generation.select(:id))
                                        .count
      return true if total_suggestions >= suggestion_volume_threshold
    end

    false
  end
end
