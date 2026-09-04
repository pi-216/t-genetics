# frozen_string_literal: true

module Identity
  # Machine-credential authentication for the /api/v1 surface (PRD-0005).
  # The client presents `Authorization: Bearer <plaintext>`; we compare the
  # SHA-256 digest against active (non-revoked) org-scoped ApiToken rows and
  # derive `current_organization` from the token. No session is involved —
  # machines are not users. A missing/invalid/revoked token answers 401 and
  # never discloses data.
  #
  # The concern overrides ApplicationController#current_organization with the
  # token's organization, so the existing org-scoped query helpers
  # (find_org_chromosome et al.) keep working unchanged on API controllers.

  module TokenAuthentication
    extend ActiveSupport::Concern

    included do
      attr_reader :current_token

      before_action :authenticate_bearer_token!
    end

    private

    def bearer_plaintext
      # Scheme matching is case-insensitive per RFC 7235.
      request.authorization.to_s[/\ABearer (.+)\z/i, 1]
    end

    def authenticate_bearer_token!
      token = Identity::ApiToken.active.find_by(token_digest: Identity::ApiToken.digest(bearer_plaintext.to_s))
      return render_unauthorized unless token

      token.update!(last_used_at: Time.current)
      @current_token = token
    end

    def current_organization
      @current_organization ||= current_token&.organization
    end

    def render_unauthorized
      render json: { errors: ['unauthorized'] }, status: :unauthorized
    end
  end
end
