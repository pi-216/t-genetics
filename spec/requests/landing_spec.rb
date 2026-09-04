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

    # PRD-0001, DEV-0003 — the trust block states that the customer keeps
    # their fitness function: we never run or evaluate it for them.
    it 'states that the customer keeps their fitness function' do
      get root_path

      expect(response.body).to include('Your fitness function stays yours')
    end
  end
end
