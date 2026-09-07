# frozen_string_literal: true

require 'rails_helper'

# PRD-0001 — public landing page, DEV-0001. The root route must render the
# product name, an explanation of the evolution loop, and a "Start free" CTA
# (public route, no auth, no DB).
RSpec.describe 'Landing page', type: :request do
  describe 'GET /' do
    it 'renders 200 with the product name' do
      get root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('TGenetics')
    end

    it 'explains the evolution loop' do
      get root_path

      expect(response.body).to include('report one number')
      expect(response.body).to include('offspring')
    end

    it 'shows a "Start free" call to action' do
      get root_path

      expect(response.body).to include('Start free')
    end

    # Founder bug report 2026-09-06 (issue #136): the landing page had no
    # entry point to the sign-in form. The shared layout renders a "Sign in"
    # link when signed out, and the landing CTA row repeats it.
    it 'shows a Sign in link that leads to the login form' do
      get root_path

      expect(response.body).to include('Sign in')
      expect(response.body).to include('href="/login"')
    end

    # PRD-0001, DEV-0003 — the trust block states that the customer keeps
    # their fitness function: we never run or evaluate it for them.
    it 'states that the customer keeps their fitness function' do
      get root_path

      expect(response.body).to include('Your fitness function stays yours')
    end

    # PRD-0001, DEV-0004 — the pricing posture teaser: a Free tier for the
    # basic loop is shown, and no paid-tier feature specifics (exploitation/
    # greed control, time-to-result optimization) are promised anywhere on
    # the page. Paid-tier features are a red line until the first payer.
    it 'shows a Free tier for the basic loop' do
      get root_path

      expect(response.body).to include('Free tier')
      expect(response.body).to include('basic loop')
    end

    it 'does not promise paid feature specifics' do
      get root_path

      expect(response.body).not_to include('exploitation')
      expect(response.body).not_to include('greed')
      expect(response.body).not_to include('time-to-result')
      expect(response.body).not_to include('insights')
    end

    # PRD-0001, DEV-0006 — the footer carries placeholder links for future
    # privacy and terms pages (the pages themselves are non-goals; the
    # links are the scope). Rendered via the shared application layout, so
    # every page inherits them.
    it 'renders privacy and terms placeholder links in the footer' do
      get root_path

      expect(response.body).to include('>Privacy<')
      expect(response.body).to include('>Terms<')
    end

    # Issue #132 (founder direction 2026-09-06) — the landing sweep: a
    # plain-language GA primer, concrete use-case cards (≥3, incl. the
    # payment-form tip case), and a genome walkthrough with REAL local
    # screenshots of the designer and experiment workspace. Every screenshot
    # is served as a same-host asset (/assets/...) so the DEV-0007
    # no-external-calls guard keeps holding.
    it 'explains what a genetic algorithm is in plain language' do
      get root_path

      expect(response.body).to include('genetic algorithm')
      expect(response.body).to include('evolutionary loop')
      expect(response.body).to include('design space')
    end

    it 'shows at least three concrete use cases including the payment tip case' do
      get root_path

      expect(response.body.scan('class="use-case-card').length).to be >= 3
      expect(response.body).to match(/payment form/i)
      expect(response.body).to match(/tip/i)
    end

    it 'walks through creating a genome with real same-host screenshots' do
      get root_path

      # Mobile imgs are the browser fallback; desktop captures ride the
      # <picture><source srcset> (issue #132: desktop + mobile widths).
      ['chromosome designer', 'experiment'].each do |alt_text|
        img = response.body[/<img[^>]*alt="[^"]*#{alt_text}[^"]*"[^>]*>/i]
        expect(img).to match(%r{src="/assets/})
      end
      %w[designer-desktop experiment-desktop designer-mobile experiment-mobile].each do |base|
        expect(response.body).to include(base)
      end
    end
  end
end
