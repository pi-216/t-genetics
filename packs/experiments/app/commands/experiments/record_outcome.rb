# frozen_string_literal: true

module Experiments
  class RecordOutcome < GLCommand::Callable
    requires performance_log: PerformanceLog, fitness_input_value: Float
    allows :outcome_metrics # Hash, will be stored as JSONB

    # Store original values for rollback
    attr_accessor :original_fitness_input_value,
                  :original_outcome_metrics,
                  :original_outcome_recorded_at

    def call
      log = context.performance_log # Already fetched and validated by GLCommand `requires`

      # Store original values for potential rollback
      self.original_fitness_input_value = log.fitness_input_value
      self.original_outcome_metrics = log.outcome_metrics
      self.original_outcome_recorded_at = log.outcome_recorded_at

      attributes_to_update = {
        fitness_input_value: context.fitness_input_value,
        outcome_recorded_at: Time.current
      }
      attributes_to_update[:outcome_metrics] = context.outcome_metrics if context.outcome_metrics.present?

      unless log.update(attributes_to_update)
        fail_command!(errors: log.errors)
      end
      # context.performance_log is already set and is the updated record
    end

    def rollback
      # This rollback is invoked if this command (RecordOutcome) succeeded,
      # but a subsequent command in a GLCommand::Chain failed.
      # It should revert the PerformanceLog to its state before this command ran.
      return unless context.performance_log&.persisted?

      # Revert to original values
      # Note: If outcome_metrics was nil initially and then set,
      # original_outcome_metrics will be nil. If it was a hash and then changed,
      # original_outcome_metrics will hold the old hash.
      context.performance_log.update(
        fitness_input_value: original_fitness_input_value,
        outcome_metrics: original_outcome_metrics,
        outcome_recorded_at: original_outcome_recorded_at
      )
      # If the update during rollback fails, there's not much more we can do here.
      # GLCommand doesn't have a built-in mechanism for "rollback of a rollback".
    end
  end
end
