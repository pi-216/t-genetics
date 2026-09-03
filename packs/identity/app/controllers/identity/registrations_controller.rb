# frozen_string_literal: true

module Identity
  # Org sign-up flow. Controllers parse input → call a Command → render from
  # the Result; they never mutate models directly (command pattern, AGENTS.md).

  class RegistrationsController < ApplicationController
    include Identity::Authentication

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
        redirect_to root_path, notice: "Welcome, #{result.user.email}!"
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
