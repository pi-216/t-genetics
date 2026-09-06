# frozen_string_literal: true

module Identity
  # Session sign-in flow (PRD-0002, DEV-0003). Mechanism: Devise/Warden
  # (issue #118) — this controller subclasses Devise::SessionsController so
  # the session is owned by Warden, while preserving the app's exact wire
  # behavior: `identity_user` params, a generic failure error, a 422
  # re-render, and the welcome-back flash. Sign-in only establishes a session
  # for an existing user — sign-up remains the mutation path (command
  # pattern, AGENTS.md).
  class SessionsController < Devise::SessionsController
    include PostAuthDestination

    # Pre-Devise wire behavior (issue #118): POST /login always processes the
    # posted credentials, even when a session already exists — the old
    # session[:user_id] flow replaced the id unconditionally, and account
    # switching mid-session is exercised by the cross-org specs. Devise's
    # stock require_no_authentication guard redirects an already-signed-in
    # user away from the login route before #create runs, so the second set
    # of credentials is silently ignored and the session keeps the OLD user
    # (org-scoped 404s then leak 200s). Skipped on this controller only.
    skip_before_action :require_no_authentication

    def new
      @user = User.new
    end

    def create
      user = User.find_by(email: email_param)

      if user&.valid_password?(password_param)
        sign_in(user)
        redirect_to after_sign_in_path_for(user), notice: "Welcome back, #{user.email}!"
      else
        @user = User.new(email: email_param)
        @user.errors.add(:base, 'Invalid email or password')
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      sign_out(:user)
      redirect_to login_path
    end

    private

    def email_param
      params.fetch(:identity_user, {}).fetch(:email, '').to_s.strip.downcase
    end

    def password_param
      params.fetch(:identity_user, {}).fetch(:password, '').to_s
    end
  end
end
