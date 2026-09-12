# frozen_string_literal: true

# Sentry pillar (AGENTS.md) — error tracking + releases + cron check-ins.
#
# DSN comes from encrypted Rails credentials (config/credentials.yml.enc),
# never from env vars or the repo. Missing DSN => SDK stays disabled (no-op),
# so dev boxes without a credentials file are silent by design.
#
# `development` is intentionally in the allowlist: this host serves the live
# app with RAILS_ENV=development (see bin/run_server.sh), so a
# production+staging-only list would mute the live site. Only hosts that
# carry the credentials file ever send events.
if (dsn = Rails.application.credentials.dig(:sentry, :dsn)).present?
  Sentry.init do |config|
    config.enabled_environments = %w[development production staging]
    config.dsn = dsn
    # Set by bin/run_server.sh on deploy so issues land on the right release.
    config.release = ENV['SENTRY_RELEASE'] if ENV['SENTRY_RELEASE'].present?
  end
end