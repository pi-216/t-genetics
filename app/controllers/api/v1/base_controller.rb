# frozen_string_literal: true

module Api
  module V1
    # Base class for the machine API (PRD-0005). Every /api/v1 endpoint is
    # authenticated by an org-scoped Bearer token; no browser session is
    # involved. JSON-only by construction — controllers render hashes/arrays.
    class BaseController < ApplicationController
      include Identity::TokenAuthentication

      private

      # Org-scoped chromosome lookup for the machine API: a chromosome outside
      # the token's organization is indistinguishable from one that does not
      # exist (404 — never data, PRD-0002 red line).
      def find_api_chromosome
        Chromosome.where(organization_id: current_organization.id)
                  .find_by(id: params[:chromosome_id] || params[:id])
      end
    end
  end
end
