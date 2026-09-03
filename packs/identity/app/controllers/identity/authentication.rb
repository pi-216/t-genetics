# frozen_string_literal: true

module Identity
  # Session/authentication helpers for the Identity context (PRD-0002).
  # Session reads/writes are a controller concern — commands never touch the
  # session (see t-chat house pattern). Reads +session+, never trusts client.

  module Authentication
    extend ActiveSupport::Concern

    included do
      helper_method :current_user, :signed_in?
    end

    private

    def current_user
      @current_user = User.find_by(id: session[:user_id]) if @current_user.nil?
    end

    def signed_in?
      current_user.present?
    end

    def sign_in(user)
      session[:user_id] = user.id
    end

    def sign_out
      session[:user_id] = nil
    end
  end
end
