# frozen_string_literal: true

module Identity
  # Creates an org-scoped API token (PRD-0005 DEV-0001 / issue #36). The
  # plaintext is generated here, stored ONLY as a SHA-256 digest, and returned
  # once through +plaintext_token+ so the owner sees it exactly once. Owner-only
  # enforcement lives at the controller layer; the command itself is org-scoped
  # and has no side effects beyond the token row.

  class CreateApiTokenCommand < GLCommand::Callable
    requires organization: Organization, name: String
    returns api_token: ApiToken, plaintext_token: String

    def call
      plaintext = ApiToken.generate_plaintext
      api_token = organization.api_tokens.build(
        name: name.to_s.strip,
        token_digest: ApiToken.digest(plaintext)
      )

      if api_token.save
        context.api_token = api_token
        context.plaintext_token = plaintext
      else
        context.error = api_token.errors.full_messages.join(', ')
      end
    end
  end
end
