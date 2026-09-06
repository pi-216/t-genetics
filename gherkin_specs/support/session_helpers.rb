# frozen_string_literal: true

module SessionHelpers
  # The signed-in Identity::User as seen by Warden on the driver's last
  # request (issue #118: sessions are Devise/Warden-owned; the hand-rolled
  # session[:user_id] key no longer exists). Nil-safe: a fresh scenario with
  # no request yet has no session to inspect.
  def signed_in_user
    page.driver.request.env['warden']&.user(:user)
  rescue Rack::Test::Error
    nil
  end
end

World(SessionHelpers)
