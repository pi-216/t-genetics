# frozen_string_literal: true

module Api
  module V1
    # Token-authenticated chromosome reads (PRD-0005 DEV-0003 / issue #38).
    # Listing is scoped to the token's organization — the same isolation rule
    # the web surface enforces via the session.
    class ChromosomesController < BaseController
      def index
        chromosomes = Chromosome.where(organization_id: current_organization.id)
        render json: chromosomes.map(&:to_hsh)
      end
    end
  end
end
