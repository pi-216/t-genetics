# frozen_string_literal: true

module Identity
  # Session sign-in flow (PRD-0002, DEV-0003. Controllers parse input →
  # authenticate → sign in via the session concern; they never mutate models
  # directly (command pattern, AGENTS.md). Sign-up remains the mutation path —
  # sign-in only establishes a session for an existing user. Sign-out (DEV-0005)
  # ends the session via the same concern.
  class SessionsController < ApplicationController
    include Identity::Authentication

    def new
      @user = User.new
    end

    def create
      user = User.find_by(email: email_param)&.authenticate(password_param)

      if user
        sign_in(user)
        redirect_to root_path, notice: "Welcome back, #{user.email}!"
      else
        @user = User.new(email: email_param)
        @user.errors.add(:base, 'Invalid email or password')
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      sign_out
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
