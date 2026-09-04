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

      # MVP: Select organism with the fewest PerformanceLog entries for this experiment.
      # This is an N+1 query pattern within the loop if not careful,
      # but for MVP, we map and then count.
      # A more optimized query could be `organisms_in_generation.min_by { |org| org.performance_logs.where(experiment_id: context.experiment.id).count }`
      # but that's still N+1.
      # Let's do a slightly more direct N+1 for clarity in MVP:
      organisms_with_log_counts = organisms_in_generation.map do |org|
        # Count logs specific to this organism AND this experiment
        log_count = PerformanceLog.where(experiment_id: context.experiment.id, organism_id: org.id).count
        { organism: org, count: log_count }
      end

      # This should not happen if organisms_in_generation is not empty, but as a safeguard:
      if organisms_with_log_counts.empty?
        fail_command!(errors: { generation: ["Could not process organisms for log counting"] })
        return
      end
      
      # Find the minimum count
      min_count = organisms_with_log_counts.map { |data| data[:count] }.min
      
      # Get all organisms with that minimum count
      least_logged_organisms_data = organisms_with_log_counts.select { |data| data[:count] == min_count }
      
      # Select one randomly from the least logged (handles ties)
      # .sample can return nil if the array is empty, but we've guarded against that.
      selected_organism_data = least_logged_organisms_data.sample
      selected_organism = selected_organism_data[:organism]

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
