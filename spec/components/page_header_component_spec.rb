# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The page header is the shared headline
# treatment for every internal surface: an optional signal kicker, the title
# in ink, an optional subtitle, an optional quiet back link, and an actions
# slot holding the surface's single amber action.
RSpec.describe PageHeaderComponent, type: :component do
  it 'renders the title in the ink headline treatment' do
    rendered = render_inline(described_class.new(title: 'Experiments', kicker: 'Workspace'))

    heading = rendered.css('h1').first
    expect(heading).not_to be_nil
    expect(heading.text.strip).to eq('Experiments')
    expect(heading['class']).to include('text-ink')
  end

  it 'renders the kicker as a signal caption label when given' do
    rendered = render_inline(described_class.new(title: 'Experiments', kicker: 'Workspace'))

    kicker = rendered.css('p').find { |p| p.text.strip == 'Workspace' }
    expect(kicker).not_to be_nil
    %w[text-signal text-caption font-medium tracking-caption uppercase].each do |utility|
      expect(kicker['class']).to include(utility)
    end
  end

  it 'renders the subtitle in muted ink when given' do
    rendered = render_inline(described_class.new(title: 'Experiments', subtitle: 'Your org loop'))

    expect(rendered.text).to include('Your org loop')
  end

  it 'renders an optional back link as a quiet ghost action' do
    rendered = render_inline(described_class.new(title: 'Organism #1', back_path: '/chromosomes', back_label: 'Chromosomes'))

    link = rendered.css('a').find { |a| a.text.strip == 'Chromosomes' }
    expect(link).not_to be_nil
    expect(link['href']).to eq('/chromosomes')
    expect(link['class']).to include('text-inkMuted')
  end

  it 'renders the actions slot' do
    rendered = render_inline(described_class.new(title: 'Experiments')) do |component|
      component.with_actions { 'New experiment' }
    end

    expect(rendered.text).to include('New experiment')
  end
end
