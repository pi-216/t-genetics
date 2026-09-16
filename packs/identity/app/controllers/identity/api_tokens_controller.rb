# frozen_string_literal: true

module Identity
  # Org-scoped API-token creation (PRD-0005 DEV-0001 / issue #36). Owner-only
  # guard mirrors the invite-code controller; the command performs the write
  # and returns the plaintext once, which lands in the flash for a single
  # render (never persisted, never re-displayed). The create form + one-time
  # reveal live on the dedicated management page (PRD-0007 / issue #189).

  class ApiTokensController < ApplicationController
    before_action :require_owner

    # PRD-0007 — the management surface: every org token (active and revoked)
    # with status, owner-only like create (the require_owner before_action
    # above guards both actions; flat owner/member roles).
    def index
      @api_tokens = current_organization.api_tokens.order(created_at: :desc)
    end

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
      redirect_to api_tokens_index_path
    end

    # PRD-0007 DEV-0004 / issue #190 — owner-only revoke of an active token.
    # Scoped through current_organization so a cross-org id is
    # indistinguishable from a missing row (404, never data). Immediate:
    # TokenAuthentication rejects a stamped token on the next API request.
    def revoke
      api_token = current_organization.api_tokens.find_by(id: params[:id])
      return head :not_found unless api_token

      result = RevokeApiTokenCommand.call(api_token: api_token)
      flash[:alert] = result.error unless result.success?
      redirect_to api_tokens_index_path
    end

    private

    def require_owner
      return if current_user&.org_membership&.owner?

      head :forbidden
    end
  end
end
