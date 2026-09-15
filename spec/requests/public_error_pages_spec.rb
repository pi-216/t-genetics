# frozen_string_literal: true

require 'rails_helper'

# QA-2026-09-14 MEDIUM-4 (issue #169): the public tunnel host rendered Rails
# development-mode error pages (routes dump + Rails.root filesystem path) to
# anonymous visitors. Root cause: consider_all_requests_local = true sets
# action_dispatch.show_detailed_exceptions for EVERY request, and the tunnel
# connection arrives from 127.0.0.1, so IP-based local detection cannot
# discriminate. The Host header alone is attacker-controlled (spoofable via
# X-Forwarded-Host / Forwarded, or a direct Host: localhost through the
# tunnel) — only the presence of cloudflared-injected proxy markers reliably
# separates public traffic from genuine local development.
RSpec.describe 'Public error pages', type: :request do
  describe 'an anonymous bad route' do
    it 'answers a clean 404 on the public hostname' do
      get '/nonexistent-xyz', headers: { 'Host' => 'tgenetics.pi216.ai' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Rails.root')
      expect(response.body).not_to include('Routing Error')
      expect(response.body).to include('The page you were looking for')
    end

    it 'answers a clean 404 when X-Forwarded-Host is spoofed to localhost' do
      get '/nonexistent-xyz',
          headers: { 'Host' => 'tgenetics.pi216.ai', 'X-Forwarded-Host' => 'localhost' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Rails.root')
      expect(response.body).not_to include('Routing Error')
    end

    it 'answers a clean 404 when Forwarded is spoofed to a local host' do
      get '/nonexistent-xyz',
          headers: { 'Host' => 'tgenetics.pi216.ai', 'Forwarded' => 'host=localhost' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Rails.root')
      expect(response.body).not_to include('Routing Error')
    end

    it 'answers a clean 404 for a spoofed Host: localhost carrying tunnel markers' do
      get '/nonexistent-xyz',
          headers: { 'Host' => 'localhost', 'CF-Connecting-IP' => '203.0.113.1', 'cf-ray' => 'a3b8ea34d9def5f8-EWR' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Rails.root')
      expect(response.body).not_to include('Routing Error')
    end

    it 'keeps the development routes-dump page for a genuine localhost request' do
      get '/nonexistent-xyz', headers: { 'Host' => 'localhost' }

      expect(response).to have_http_status(:not_found)
      expect(response.body).to include('Routing Error')
      expect(response.body).to include('Rails.root')
    end
  end
end
