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

  # PRD-0006 DEV-0002 — the landing primary CTA is the amber signal button.
  # The @javascript BDD scenario measures computed styles (signal fill,
  # onSignal text, mono caption face) in headless Chrome; this request spec
  # is the non-JS regression net over the CTA's rendered class list — the
  # token utilities must be on the element for the computed styles to hold.
  it 'renders the landing primary CTA with the button-primary token utilities' do
    get root_path

    cta_classes = response.body[/<a[^>]*class="([^"]*landing-cta-link[^"]*)"[^>]*>/i, 1]
    %w[bg-signal text-onSignal font-data text-caption font-medium tracking-caption rounded-md py-3 px-5.5].each do |utility|
      expect(cta_classes).to include(utility)
    end
  end

  # PRD-0006 DEV-0003 — the landing page declares the brand structure.
  # The @javascript BDD scenario measures computed styles (kickers in signal,
  # hero h1 in the display typeface, hero on base) in headless Chrome; this
  # request spec is the non-JS regression net over the rendered class lists —
  # the token utilities must be on the elements for the computed styles to
  # hold.
  it 'renders the landing section kickers with the kicker token utilities' do
    get root_path

    kicker_elements = response.body.scan(/class="([^"]*landing-kicker[^"]*)"/)
    expect(kicker_elements.length).to be >= 3
    kicker_utilities = %w[font-data text-caption font-medium tracking-caption uppercase text-signal]
    kicker_elements.each do |(classes)|
      kicker_utilities.each do |utility|
        expect(classes).to include(utility)
      end
    end
  end

  it 'renders the landing hero h1 with the display typeface utilities on base' do
    get root_path

    hero_section = response.body[/<section[^>]*class="([^"]*landing-hero[^"]*)"[^>]*>/i, 1]
    expect(hero_section).to include('bg-base')

    hero_title = response.body[/<h1[^>]*class="([^"]*)"[^>]*>TGenetics/i, 1]
    %w[font-display text-display font-bold tracking-display].each do |utility|
      expect(hero_title).to include(utility)
    end
  end
end
