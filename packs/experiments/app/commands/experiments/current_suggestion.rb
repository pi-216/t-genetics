# frozen_string_literal: true

module Experiments
  # PRD-0005 Q4 (issue #131) — read-only "current suggestion". A suggestion is
  # a LONG-LIVED object (suggested → shown → outcome) and the gap between
  # "shown a suggestion" and "they report the outcome" can be days or weeks —
  # canonical case: tip-amount suggestions on a payment form, where many
  # customers each get a presentation and the outcome is reported later,
  # decoupled and batched. The token API's POST /suggestion draws a NEW random
  # organism every call, so re-presenting the SAME suggestion across sessions
  # needs a read.
  #
  # This command returns the experiment's current PENDING suggestion — the
  # most recent PerformanceLog that (a) has no customer-reported fitness yet
  # (fitness_input_value is nil) and (b) belongs to the experiment's CURRENT
  # generation. It NEVER creates a PerformanceLog (read-only counterpart to
  # RequestSuggestion). A re-read is stable until an outcome is recorded (the
  # log gains a fitness value and drops out of the pending set) or the
  # generation evolves (the organism's generation is no longer current). When
  # nothing is pending, performance_log is nil — the caller renders an
  # explicit empty state, never silent.
  class CurrentSuggestion < GLCommand::Callable
    requires experiment: Experiment
    returns :performance_log

    def call
      current_generation = context.experiment.current_generation
      unless current_generation
        context.performance_log = nil
        return
      end

      # Most recent pending log whose organism is in the CURRENT generation.
      # Scoping to the current generation is what makes evolution invalidate
      # the previous suggestion's "current" status.
      context.performance_log = PerformanceLog.where(experiment_id: context.experiment.id)
                                              .where(fitness_input_value: nil)
                                              .where(organism_id: current_generation.organisms.select(:id))
                                              .order(id: :desc)
                                              .first
    end
  end
end
