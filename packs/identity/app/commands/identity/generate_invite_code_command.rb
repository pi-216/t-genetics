# frozen_string_literal: true

module Identity
  # Fetches the org's invite code, generating one on first use (PRD-0002,
  # DEV-0006 / issue #16). Owner-only enforcement lives at the controller
  # layer; the command itself is org-scoped and idempotent — repeated calls
  # reuse the code (v1: one code per org, kept stable until invalidation).
  # A concurrent generate racing the unique-org constraint falls back to the
  # winner's code instead of failing.

  class GenerateInviteCodeCommand < GLCommand::Callable
    requires organization: Organization
    returns invite_code: InviteCode

    def call
      existing = organization.invite_code
      return context.invite_code = existing if existing

      code = organization.build_invite_code(code: InviteCode.generate_code)
      if code.save
        context.invite_code = code
      else
        winner = organization.reload.invite_code
        if winner
          context.invite_code = winner
        else
          context.error = code.errors.full_messages.join(', ')
        end
      end
    end
  end
end
