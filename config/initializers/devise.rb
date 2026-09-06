# frozen_string_literal: true

# Load the ActiveRecord ORM adapter — registers Devise::Models (the `devise`
# class method) into ActiveRecord::Base via ActiveSupport.on_load.
require 'devise/orm/active_record'

# Devise 5 configuration (issue #118 — standard auth tooling replacing the
# hand-rolled has_secure_password stack). Defaults mirror the generated
# initializer; only what the app needs is set explicitly.
Devise.setup do |config|
  # The e-mail used in password-reset messages (dev/self-hosted delivery
  # only — no external mail infra, red line).
  config.mailer_sender = 'no-reply@tgenetics.local'

  # Email is treated case-insensitively everywhere: downcased before
  # validation (and before save), so the case-sensitive unique index on
  # `email` behaves case-insensitively — same contract the model had before.
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # Session holds only the Warden user key; HTTP Basic auth must not be
  # persisted to the session.
  config.skip_session_storage = [:http_auth]

  # bcrypt cost. Tests hash once (fast); dev/prod use the standard cost.
  config.stretches = Rails.env.test? ? 1 : 12

  # :recoverable — reset links expire after 6 hours.
  config.reset_password_within = 6.hours

  # The app's sign-out verb is POST /logout (Devise's default is DELETE).
  config.sign_out_via = :post

  # :validatable — password must be 6..128 characters (standard Devise);
  # the 72-byte bcrypt ceiling applies at hashing time.
  config.password_length = 6..128

  # Devise controllers subclass ApplicationController (which skips CSRF
  # verification app-wide — see application_controller.rb).
  config.parent_controller = 'ApplicationController'
end
