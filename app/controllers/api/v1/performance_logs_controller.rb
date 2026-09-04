# frozen_string_literal: true

module Api
  module V1
    # Token-authenticated outcome reporting (PRD-0005 DEV-0009 / issue #44).
    # The machine reports ONE fitness number for the organism it was suggested
    # (the suggestion's PerformanceLog); Experiments::RecordOutcome persists it
    # as the only fitness-bearing input in the product. The log is scoped to
    # the token's organization through experiment → chromosome — a cross-org or
    # unknown log id answers 404 (never data), and a malformed or missing
    # fitness value answers 422 with error keys.
    class PerformanceLogsController < BaseController
      def outcome
        log = PerformanceLog.joins(experiment: :chromosome)
                            .where(chromosomes: { organization_id: current_organization.id })
                            .find_by(id: params[:id])
        return render_not_found unless log

        fitness = outcome_fitness_input_value
        return if performed?

        result = Experiments::RecordOutcome.call(performance_log: log, fitness_input_value: fitness)

        if result.success?
          render json: log.to_h
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      private

      # The machine payload is wrapped like every v1 write
      # ({ "performance_log": { "fitness_input_value": 0.81 } }). The required
      # wrapper/key are enforced by params.expect (missing → 422 with error
      # keys via the base controller's ParameterMissing rescue); a value that
      # cannot be a number answers the same 422 contract.
      def outcome_fitness_input_value
        Float(params.expect(performance_log: [:fitness_input_value])[:fitness_input_value])
      rescue ArgumentError, TypeError
        render json: { errors: { fitness_input_value: ['must be a number'] } },
               status: :unprocessable_content
        nil
      end

      def render_not_found
        render json: { errors: ['not_found'] }, status: :not_found
      end
    end
  end
end
