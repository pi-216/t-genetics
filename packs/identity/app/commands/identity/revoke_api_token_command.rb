# frozen_string_literal: true

module Identity
  # Revokes an org-scoped API token (PRD-0007 DEV-0004 / issue #190).
  # Revocation is immediate: TokenAuthentication authenticates only
  # non-revoked tokens (ApiToken.active), so a stamped revoked_at kills API
  # access on the next request. Idempotent — re-revoking an already-revoked
  # token is a no-op success; the web UI only exposes the control for active
  # tokens. Owner-only enforcement lives at the controller layer.

  class RevokeApiTokenCommand < ApplicationCommand
    requires api_token: ApiToken

    def call
      api_token.revoked_at = Time.current
      if api_token.save
        context.api_token = api_token
      else
        context.error = api_token.errors.full_messages.join(', ')
      end
    end
  end
end
