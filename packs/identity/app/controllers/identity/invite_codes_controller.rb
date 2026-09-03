# frozen_string_literal: true

module Identity
  # Owner-only invite-code page (PRD-0002 DEV-0006 / issue #16). GET shows
  # the org's current code (or a generate prompt); POST fetch-or-creates one.
  # Flat-role guard: owner sees it, member/outsider gets 403 — the code is
  # org data, never disclosed cross-org. Commands do the writes (command
  # pattern); the controller only guards and renders.

  class InviteCodesController < ApplicationController
    include Identity::Authentication

    before_action :require_owner

    def show
      @invite_code = current_user.organization&.invite_code
    end

    def create
      GenerateInviteCodeCommand.call(organization: current_user.organization)
      redirect_to organization_invite_code_path
    end

    private

    def require_owner
      return if current_user&.org_membership&.owner?

      head :forbidden
    end
  end
end
