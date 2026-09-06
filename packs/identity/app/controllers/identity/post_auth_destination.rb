# frozen_string_literal: true

module Identity
  # Devise-standard post-auth destinations (founder bug report 2026-09-06,
  # issue #136): after signing in, signing up, or joining an organization,
  # land in the user's org workspace (the experiments index) — never back on
  # the public landing page. These are Devise's named hooks
  # (after_sign_in_path_for / after_sign_up_path_for /
  # after_inactive_sign_up_path_for), so the redirect contract stays covered
  # by standard Devise tooling; the identity controllers call sign_in and
  # then redirect through them instead of hardcoding root_path.
  module PostAuthDestination
    private

    def after_sign_in_path_for(_resource_or_scope)
      experiments_url
    end

    def after_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end

    def after_inactive_sign_up_path_for(resource)
      after_sign_in_path_for(resource)
    end
  end
end
