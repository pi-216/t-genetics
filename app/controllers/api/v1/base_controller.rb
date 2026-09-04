# frozen_string_literal: true

module Api
  module V1
    # Base class for the machine API (PRD-0005). Every /api/v1 endpoint is
    # authenticated by an org-scoped Bearer token; no browser session is
    # involved. JSON-only by construction — controllers render hashes/arrays.
    class BaseController < ApplicationController
      include Identity::TokenAuthentication

      # PRD-0005 contract: malformed payloads answer 422 with error keys, and
      # the rswag artifacts document only 201/422 for the write endpoints — no
      # 400 anywhere. A body missing a required wrapper key would otherwise
      # surface Rails' default ActionController::ParameterMissing 400; rescue
      # it here so every endpoint answers the same malformed-payload contract.
      rescue_from ActionController::ParameterMissing do |exception|
        render json: { errors: { exception.param.to_s => ['is required'] } },
               status: :unprocessable_content
      end

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
