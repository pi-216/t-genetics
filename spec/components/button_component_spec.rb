# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The button is the single action control for
# internal surfaces. Variants map to the Lab Instrument tokens: primary = the
# amber signal fill with dark onSignal text (the locked button-primary spec),
# secondary = transparent surface with a hairline ring, danger = the red
# signal, ghost = a quiet text link. It renders as a link, a form submit
# (button_to), or a plain/submit button — whichever the caller's markup needs.
RSpec.describe ButtonComponent, type: :component do
  it 'renders the primary variant with the locked button-primary token utilities' do
    rendered = render_inline(described_class.new(label: 'Create experiment', variant: :primary))

    button = rendered.css('button').first
    %w[bg-signal text-onSignal font-data text-caption font-medium tracking-caption rounded-md].each do |utility|
      expect(button['class']).to include(utility)
    end
  end

  it 'renders the secondary variant with a hairline ring on the dark surface' do
    rendered = render_inline(described_class.new(label: 'Cancel', variant: :secondary))

    button = rendered.css('button').first
    expect(button['class']).to include('border-line')
    expect(button['class']).to include('text-ink')
  end

  it 'renders the danger variant on the red signal' do
    rendered = render_inline(described_class.new(label: 'Delete', variant: :danger))

    button = rendered.css('button').first
    expect(button['class']).to include('bg-danger')
  end

  it 'renders the ghost variant as a quiet muted action' do
    rendered = render_inline(described_class.new(label: 'Back', variant: :ghost))

    button = rendered.css('button').first
    expect(button['class']).to include('text-inkMuted')
  end

  # Issue #203 — the page-header back link is a quiet text affordance that
  # must sit flush with the heading block, so the back variant drops the base
  # horizontal hit-target padding. Real buttons (ghost included) keep it.
  it 'renders the back variant flush-left with the quiet ghost treatment' do
    rendered = render_inline(described_class.new(label: 'Mixed genome',
                                                 href: '/chromosomes/1',
                                                 variant: :back))

    link = rendered.css('a').first
    expect(link['class']).to include('pl-0')
    expect(link['class']).to include('text-inkMuted')
  end

  it 'keeps the horizontal hit-target padding on real ghost buttons' do
    rendered = render_inline(described_class.new(label: 'Cancel', variant: :ghost))

    button = rendered.css('button').first
    expect(button['class']).to include('px-4')
  end

  it 'renders as a link when an href is given' do
    rendered = render_inline(described_class.new(label: 'History', href: '/experiments/1/history', variant: :secondary))

    link = rendered.css('a').first
    expect(link['href']).to eq('/experiments/1/history')
    expect(link.text.strip).to eq('History')
  end

  it 'renders a submit button with a commit name/value (designer round trips)' do
    rendered = render_inline(described_class.new(label: 'Add allele', type: :submit, name: 'commit', value: 'Add allele'))

    button = rendered.css('button').first
    expect(button['type']).to eq('submit')
    expect(button['name']).to eq('commit')
    expect(button['value']).to eq('Add allele')
  end

  it 'renders a form-wrapping button when a form action is given' do
    rendered = render_inline(described_class.new(label: 'Request suggestion',
                                                 form_action: '/experiments/1/suggestion',
                                                 method: :post, variant: :primary))

    expect(rendered.css('form').first['action']).to eq('/experiments/1/suggestion')
    button = rendered.css('button').first
    expect(button['class']).to include('bg-signal')
  end

  # Finding #147 (T1) — loop actions re-render (200/422), never redirect, so a
  # Turbo-intercepted form discards every response in a real browser. The
  # form element (not the button) must carry data-turbo="false" so the POST
  # round trip renders as classic HTML.
  it 'renders form_data as attributes on the form element (Turbo opt-out)' do
    rendered = render_inline(described_class.new(label: 'Request suggestion',
                                                 form_action: '/experiments/1/suggestion',
                                                 method: :post,
                                                 form_data: { turbo: false }))

    form = rendered.css('form').first
    expect(form['data-turbo']).to eq('false')
  end
end
