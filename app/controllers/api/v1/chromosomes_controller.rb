# frozen_string_literal: true

module Api
  module V1
    # Token-authenticated chromosome reads/writes (PRD-0005 DEV-0003 / issue
    # #38 for index; DEV-0006 / issue #41 for create). Everything is scoped to
    # the token's organization — the same isolation rule the web surface
    # enforces via the session. The client can never choose the organization:
    # writes always land in the token's org (cross-org 403/404 red line).
    class ChromosomesController < BaseController
      def index
        chromosomes = Chromosome.where(organization_id: current_organization.id)
        render json: chromosomes.map(&:to_hsh)
      end

      def create
        chromosome = Chromosome.new(chromosome_params.merge(organization: current_organization))

        if chromosome.save
          render json: chromosome.to_hsh, status: :created
        else
          render json: { errors: chromosome.errors }, status: :unprocessable_content
        end
      end

      private

      # Only the name is client-settable; organization always comes from the
      # authenticated token's organization.
      def chromosome_params
        params.expect(chromosome: [:name])
      end
    end
  end
end
