# frozen_string_literal: true

module Identity
  # Org sign-up flow (PRD-0002). Mechanism: Devise (issue #118) — subclasses
  # Devise::RegistrationsController for the Warden session, while the custom
  # SignUpCommand stays the single path to a new org: it creates
  # user + organization + owner membership atomically. Controllers parse
  # input → call a Command → render from the Result; they never mutate
  # models directly (command pattern, AGENTS.md).
  class RegistrationsController < Devise::RegistrationsController
    include PostAuthDestination

    def new
      @user = User.new
    end

    def create
      result = SignUpCommand.call(
        email: registration_params.fetch(:email, ''),
        password: registration_params.fetch(:password, ''),
        organization: registration_params.fetch(:organization_name, '')
      )

      if result.success?
        sign_in(result.user)
        redirect_to after_sign_up_path_for(result.user), notice: "Welcome, #{result.user.email}!"
      else
        @user = User.new(
          email: registration_params.fetch(:email, ''),
          organization_name: registration_params.fetch(:organization_name, '')
        )
        @user.errors.add(:base, result.full_error_message)
        render :new, status: :unprocessable_content
      end
    end

    private

    def registration_params
      params.fetch(:identity_user, {}).permit(:email, :organization_name, :password)
    end
  end
end
