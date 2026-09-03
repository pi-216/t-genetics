# frozen_string_literal: true

module Identity
  # Organization settings (PRD-0002 DEV-0008 / issue #18). Any signed-in
  # member of an org may view the page; the member-management and token-management
  # sections render owner-only (flat roles; members never see them).
  class SettingsController < ApplicationController
    include Identity::Authentication

    before_action :require_signed_in

    def show
      render_org_not_found unless current_organization
    end

    private

    def require_signed_in
      redirect_to login_path unless signed_in?
    end
  end
end
