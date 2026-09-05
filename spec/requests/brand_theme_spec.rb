# frozen_string_literal: true

require 'rails_helper'

# PRD-0006 DEV-0001 — the shared layout renders the brand dark theme.
# The @javascript BDD scenario (gherkin_specs/brand/brand_tokens.feature)
# measures computed styles in headless Chrome; this request spec is the
# non-JS regression net over the rendered HTML of every page: the body tag
# carries the brand base/ink utilities and no teal scaffold class appears
# anywhere in the page.
RSpec.describe 'Brand dark theme (shared layout)', type: :request do
  it 'renders the body on the brand base color with ink text' do
    get root_path

    body_tag = response.body[/<body[^>]*>/]
    aggregate_failures do
      expect(body_tag).to include('bg-base')
      expect(body_tag).to include('text-ink')
      expect(body_tag).not_to include('teal')
    end
  end

  it 'renders no scaffold teal color classes on any page element' do
    get root_path

    expect(response.body).not_to match(/teal/)
  end
end
