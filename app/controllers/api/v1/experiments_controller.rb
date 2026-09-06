# frozen_string_literal: true

module Api
  module V1
    # Token-authenticated experiment lifecycle (PRD-0005 DEV-0007 / issue #42).
    # Create runs the engine's Experiments::Setup command, which mints the
    # initial generation and population for the chosen chromosome; the client
    # only ever names a chromosome, and that chromosome must belong to the
    # token's organization (cross-org ids answer 404 — never data). Index lists
    # only the token org's experiments, joined through their chromosome.
    class ExperimentsController < BaseController
      def index
        experiments = Experiment.joins(:chromosome)
                                .includes(:chromosome)
                                .where(chromosomes: { organization_id: current_organization.id })
                                .order(:id)
        render json: experiments.map(&:to_h)
      end

      def create
        chromosome = Chromosome.where(organization_id: current_organization.id)
                               .find_by(id: params.dig(:experiment, :chromosome_id))
        return render_not_found unless chromosome

        result = Experiments::Setup.call(chromosome:, external_entity: chromosome)

        if result.success?
          render json: result.experiment.to_h, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      # PRD-0005 DEV-0008 (issue #43) — machines request a suggestion with a
      # token. Runs the engine's Experiments::RequestSuggestion command against
      # the token org's experiment and returns the suggested organism with its
      # allele values (the command records the suggestion's PerformanceLog). A
      # cross-org or unknown experiment id answers 404 — never data; a command
      # failure (e.g. no current generation) answers 422 with error keys.
      def suggestion
        experiment = Experiment.joins(:chromosome)
                               .where(chromosomes: { organization_id: current_organization.id })
                               .find_by(id: params[:id])
        return render_not_found unless experiment

        result = Experiments::RequestSuggestion.call(experiment:)

        if result.success?
          render json: result.organism.to_hsh
        else
          render json: { errors: result.errors }, status: :unprocessable_content
        end
      end

      # PRD-0005 Q4 (issue #131) — read the experiment's current PENDING
      # suggestion (the most recent unreported PerformanceLog whose organism is
      # in the current generation) without creating a new log. This is how a
      # machine re-presents the SAME long-lived suggestion across sessions —
      # POST /suggestion draws a new random organism and must not be called
      # just to re-read. Org-scoped (cross-org/unknown id solves 404, never
      # data); when nothing is pending the response is an explicit 200 with
      # nulls, never silent (404 stays reserved for not-found/cross-org).
      def current_suggestion
        experiment = Experiment.joins(:chromosome)
                               .where(chromosomes: { organization_id: current_organization.id })
                               .find_by(id: params[:id])
        return render_not_found unless experiment

        result = Experiments::CurrentSuggestion.call(experiment:)
        log = result.performance_log

        if log
          render json: { performance_log: log.to_h, organism: log.organism.to_hsh }
        else
          render json: { performance_log: nil, organism: nil }
        end
      end

      private

      def render_not_found
        render json: { errors: ['not_found'] }, status: :not_found
      end
    end
  end
end
