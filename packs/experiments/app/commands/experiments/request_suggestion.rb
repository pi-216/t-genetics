# frozen_string_literal: true

module Experiments
  class RequestSuggestion < GLCommand::Callable
    requires experiment: Experiment
    returns :organism, :performance_log

    def call
      # PRD-0003 DEV-0005 (issue #72): the next loop action on a ripe
      # experiment triggers the evolution before suggesting. RequestSuggestion
      # is the shared loop action for the web UI and the machine API
      # (PRD-0005), so the auto-evolve lives here — a suggestion is always
      # served from the newest generation after a ripe evolution. Also
      # self-activates a pending experiment (pending → running, mirroring
      # EvaluateAndEvolve), otherwise a created experiment could never become
      # ripe and the loop would stall in production.
      context.experiment.start! if context.experiment.may_start?
      evolve_if_ripe!

      current_generation = context.experiment.current_generation
      unless current_generation
        fail_command!(errors: { experiment: ['does not have a current generation'] })
        return
      end

      organisms_in_generation = current_generation.organisms
      if organisms_in_generation.empty?
        fail_command!(errors: { generation: ['current generation has no organisms'] })
        return
      end

      # Founder ruling 2026-09-04 (issue #130, "Suggestion semantics" in
      # docs/design-sprint/ph2/ux-concept.md): a suggestion is a UNIFORM RANDOM
      # draw from the current generation's UNTESTED pool — organisms without a
      # reported fitness for this experiment (a PerformanceLog with a
      # fitness_input_value). A reported organism is never suggested again
      # while the generation is current; a suggested-but-unreported organism
      # stays in the pool (its pending log carries no fitness value — drawing
      # it again just samples it more, which is fine for the payment-form use
      # case). Exploit mode (proportional sampling of known-good organisms) is
      # paid tier and deliberately absent. One grouped query, no N+1.
      reported_organism_ids = PerformanceLog.where(
        experiment_id: context.experiment.id,
        organism_id: organisms_in_generation.select(:id)
      ).where.not(fitness_input_value: nil).distinct.pluck(:organism_id)

      untested_organisms = organisms_in_generation.reject do |org|
        reported_organism_ids.include?(org.id)
      end

      if untested_organisms.empty?
        fail_command!(errors: { generation: ['every organism in the current generation already has a reported fitness'] })
        return
      end

      selected_organism = untested_organisms.sample

      @performance_log = PerformanceLog.new(
        experiment: context.experiment,
        organism: selected_organism,
        suggested_at: Time.current
      )

      unless @performance_log.save
        fail_command!(errors: @performance_log.errors)
        return
      end

      context.organism = selected_organism
      context.performance_log = @performance_log
    end

    def rollback
      # This rollback is invoked if this command (RequestSuggestion) succeeded,
      # but a subsequent command in a GLCommand::Chain failed.
      # It should undo the created PerformanceLog.
      @performance_log.destroy if @performance_log&.persisted?
      # Also clear from context if it was set
      context.performance_log = nil if @performance_log&.destroyed?
      context.organism = nil if @performance_log&.destroyed? # Organism wasn't created by this command
    end

    private

    # PRD-0003 DEV-0005 (issue #72): when the experiment is ripe
    # (ripe_for_evolution?), the next loop action runs EvaluateAndEvolve first,
    # so the suggestion is served from the NEW generation. A failed evolution
    # fails the suggestion (never silently suggest stale organisms); the
    # evolution itself is transaction-protected and its rollback handles the
    # chain case.
    def evolve_if_ripe!
      return unless context.experiment.ripe_for_evolution?

      evolve_result = EvaluateAndEvolve.call(experiment: context.experiment)
      return if evolve_result.success?

      fail_command!(errors: evolve_result.errors)
    end
  end
end
