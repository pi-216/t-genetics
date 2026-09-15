# frozen_string_literal: true

# Development boots with consider_all_requests_local = true, which sets
# action_dispatch.show_detailed_exceptions for every request — including the
# public tunnel host, where anonymous visitors get the routes dump and the
# filesystem path (QA-2026-09-14 MEDIUM-4). The Cloudflare tunnel connects
# from 127.0.0.1, so IP-based request.local? cannot discriminate, and the Host
# header is attacker-controlled (spoofable via X-Forwarded-Host or a direct
# Host: localhost). The only trustworthy signal is the absence of proxy/tunnel
# markers: cloudflared injects X-Forwarded-*, CF-Connecting-IP and cf-ray
# origin-side, and anonymous clients cannot strip or spoof them through the
# edge. We only ever downgrade the flag — never upgrade it — so production
# (boot flag already false) is untouched and fail-closed.
class LocalOnlyDetailedExceptions
  LOCAL_HOSTS = %w[localhost 127.0.0.1 0.0.0.0 ::1 [::1]].freeze
  LOCAL_SUFFIXES = %w[.localhost .test .local].freeze
  PROXY_MARKERS = %w[HTTP_X_FORWARDED_HOST HTTP_X_FORWARDED_FOR HTTP_CF_CONNECTING_IP HTTP_CF_RAY HTTP_FORWARDED].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    request = ActionDispatch::Request.new(env)
    env['action_dispatch.show_detailed_exceptions'] = false unless local_request?(request)
    @app.call(env)
  end

  private

  def local_request?(request)
    return false if PROXY_MARKERS.any? { |header| request.get_header(header).present? }

    host = request.host.to_s.downcase
    LOCAL_HOSTS.include?(host) || LOCAL_SUFFIXES.any? { |suffix| host.end_with?(suffix) }
  end
end
