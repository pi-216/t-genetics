# frozen_string_literal: true

module Experiments
  class EvaluateAndEvolve < GLCommand::Callable
    requires experiment: Experiment
    returns :new_generation # The newly created and populated Generation

    # For rollback
    attr_accessor :previous_generation_id_for_rollback,
                  :new_generation_id_for_rollback,
                  :original_organism_fitness_values_for_rollback # Hash { organism_id => original_fitness }

    def call
      # The parent generation this call intends to evolve — captured BEFORE
      # the row lock so a concurrent evolution landing while we wait is
      # caught by the compare-and-set below.
      parent_generation = context.experiment.current_generation
      fail_command!(errors: { experiment: ['does not have a current generation to evaluate'] }) unless parent_generation

      # PRD-0003 DEV-0006 (issue #73): evolution must be idempotent — a
      # double-fire (two loop actions racing on the same ripe state: a
      # double-click, web + machine API at once, or a client retry) must not
      # create two generations. with_lock serializes the evolution on the
      # experiment row and reloads it (resetting the association cache), so
      # the re-read below sees the freshest committed generation. If it is
      # no longer the parent this call observed, a concurrent evolution
      # already bred the offspring — adopt the winner, don't create a sibling.
      context.experiment.with_lock do
        current_generation = context.experiment.current_generation

        if current_generation.id != parent_generation.id
          context.new_generation = current_generation
          return
        end

        # Ensure experiment is running
        context.experiment.start! if context.experiment.may_start?
        fail_command!(errors: { experiment: ["must be in 'running' state to evaluate and evolve (current: #{context.experiment.status})"] }) unless context.experiment.running?

        organisms_to_evaluate = current_generation.organisms.to_a
        fail_command!(errors: { generation: ['current generation has no organisms to evaluate'] }) if organisms_to_evaluate.empty?

        breed_offspring!(current_generation, organisms_to_evaluate)
      end
    rescue ActiveRecord::Rollback
      # Errors already set by fail_command!
      # Clear context returns if transaction failed
      context.new_generation = nil
    end

    def rollback
      # Revert the experiment's current_generation, destroy the offspring
      # generation, and restore the previous generation's fitness values.

      return unless new_generation_id_for_rollback && previous_generation_id_for_rollback

      experiment_to_revert = context.experiment
      newly_created_generation = Generation.find_by(id: new_generation_id_for_rollback)
      previous_generation = Generation.find_by(id: previous_generation_id_for_rollback)

      if experiment_to_revert && previous_generation
        experiment_to_revert.current_generation = previous_generation
        experiment_to_revert.save
      end

      if previous_generation && original_organism_fitness_values_for_rollback.present?
        Organism.where(id: original_organism_fitness_values_for_rollback.keys).each do |org|
          org.update(fitness: original_organism_fitness_values_for_rollback[org.id])
        end
      end

      newly_created_generation.destroy if newly_created_generation&.persisted?

      context.new_generation = nil
    end

    private

    # Evaluate fitness, create/breed the offspring generation, and swap the
    # experiment's current generation — one transaction, atomic rollback.
    def breed_offspring!(current_generation, organisms_to_evaluate)
      # For potential full rollback if this command is part of a chain
      self.previous_generation_id_for_rollback = current_generation.id
      self.original_organism_fitness_values_for_rollback = {}

      ActiveRecord::Base.transaction do
        # 1. Evaluate fitness
        organisms_to_evaluate.each do |organism|
          original_organism_fitness_values_for_rollback[organism.id] = organism.fitness

          performance_logs = PerformanceLog.where(
            experiment_id: context.experiment.id,
            organism_id: organism.id
          ).where.not(fitness_input_value: nil) # Only consider logs with fitness input

          new_fitness = if performance_logs.any?
                          performance_logs.average(:fitness_input_value)
                        else
                          0.0 # Default fitness if no relevant performance logs
                        end

          unless organism.update(fitness: new_fitness)
            errors.add(:base, "Failed to update fitness for organism #{organism.id}")
            errors.merge!(organism.errors)
            fail_command!(errors:)
          end
        end

        # 2. Create the offspring generation record
        population_size = context.experiment.configuration.fetch('population_size', 10) # string/symbol key consistency

        @new_offspring_generation = Generation.new(
          chromosome: context.experiment.chromosome,
          iteration: current_generation.iteration + 1
        )
        unless @new_offspring_generation.save
          errors.add(:base, "Failed to create new generation record for evolution.")
          errors.merge!(@new_offspring_generation.errors)
          fail_command!(errors:)
        end
        self.new_generation_id_for_rollback = @new_offspring_generation.id

        # 3. Breed: Generations::New populates the offspring from the parents
        evolve_result = Generations::New.call(
          parent_generation: current_generation, # Now has updated fitness values
          offspring_generation: @new_offspring_generation,
          organism_count: population_size
        )

        unless evolve_result.success?
          errors.add(:base, "Evolution (Generations::New) failed.")
          errors.merge!(evolve_result.errors)
          # Offspring was created but not populated; the transaction rollback destroys it.
          fail_command!(errors:)
        end

        # 4. Update the experiment's current generation
        context.experiment.current_generation = @new_offspring_generation
        unless context.experiment.save
          errors.add(:base, "Failed to update experiment with new current generation.")
          errors.merge!(context.experiment.errors)
          fail_command!(errors:)
        end

        context.new_generation = @new_offspring_generation
      end # End of transaction
    end
  end
end
