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

      private

      def render_not_found
        render json: { errors: ['not_found'] }, status: :not_found
      end
    end
  end
end
