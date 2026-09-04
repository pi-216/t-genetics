# frozen_string_literal: true

module Identity
  # Org-scoped API-token creation (PRD-0005 DEV-0001 / issue #36). Owner-only
  # guard mirrors the invite-code controller; the command performs the write
  # and returns the plaintext once, which lands in the flash for a single
  # render (never persisted, never re-displayed). The create form lives on the
  # organization settings page.

  class ApiTokensController < ApplicationController
    include Identity::Authentication

    before_action :require_owner

    def create
      result = CreateApiTokenCommand.call(
        organization: current_user.organization,
        name: params.fetch(:api_token, {}).fetch(:name, '')
      )

      if result.plaintext_token
        flash[:api_token] = result.plaintext_token
      else
        flash[:alert] = result.error
      end
      redirect_to settings_path
    end

    private

    def require_owner
      return if current_user&.org_membership&.owner?

      head :forbidden
    end
  end
end
