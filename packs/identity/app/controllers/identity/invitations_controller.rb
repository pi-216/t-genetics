# frozen_string_literal: true

module Identity
  # Join-an-organization flow via an owner-generated invite code
  # (PRD-0002 DEV-0007). Controllers parse input → call the Command → render
  # from the Result; they never mutate models directly (command pattern,
  # AGENTS.md). Sign-in of the new member happens at the controller layer,
  # like registration.
  class InvitationsController < ApplicationController
    include Identity::Authentication

    def new
      @user = User.new
    end

    def create
      result = JoinCommand.call(
        invite_code: join_params.fetch(:invite_code, ''),
        email: join_params.fetch(:email, ''),
        password: join_params.fetch(:password, '')
      )

      if result.success?
        sign_in(result.user)
        redirect_to root_path, notice: "Welcome, #{result.user.email}! You joined #{result.organization.name}."
      else
        @user = User.new(email: join_params.fetch(:email, ''))
        @user.errors.add(:base, result.full_error_message)
        render :new, status: :unprocessable_content
      end
    end

    private

    def join_params
      raw = params[:identity_user]
      return {} unless raw.respond_to?(:permit)

      raw.permit(:invite_code, :email, :password)
    end
  end
end
