# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The badge is the small status/ripe marker:
# a short-radius (never pill) chip with a muted surface default and intent
# variants in the signal colors — used for experiment status, evolution
# ripeness, and organism values.
RSpec.describe BadgeComponent, type: :component do
  it 'renders the default variant as a raised-surface chip' do
    rendered = render_inline(described_class.new(text: 'pending'))

    badge = rendered.css('span.badge').first
    expect(badge).not_to be_nil
    expect(badge['class']).to include('bg-raised')
    expect(badge.text.strip).to eq('pending')
  end

  it 'renders the signal variant for the amber intent' do
    rendered = render_inline(described_class.new(text: 'ripe', intent: :signal))

    badge = rendered.css('span.badge').first
    expect(badge['class']).to include('text-signal')
  end

  it 'renders the good variant for success states' do
    rendered = render_inline(described_class.new(text: 'cleared', intent: :good))

    badge = rendered.css('span.badge').first
    expect(badge['class']).to include('text-good')
  end

  it 'renders the danger variant for errors' do
    rendered = render_inline(described_class.new(text: 'failed', intent: :danger))

    badge = rendered.css('span.badge').first
    expect(badge['class']).to include('text-danger')
  end

  it 'renders block content over the text label' do
    rendered = render_inline(described_class.new) { 'custom' }

    expect(rendered.text.strip).to eq('custom')
  end
end
