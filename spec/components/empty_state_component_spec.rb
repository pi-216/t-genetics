# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The empty state is the explicit
# no-data surface (PRD-0004 convention): a dashed hairline panel with a
# title, a muted body line, and an optional action. Never a bare paragraph.
RSpec.describe EmptyStateComponent, type: :component do
  it 'renders the title and body in the panel' do
    rendered = render_inline(described_class.new(title: 'No suggestion is available',
                                                 body: 'The current generation has no organisms to suggest.'))

    expect(rendered.css('h3').text).to include('No suggestion is available')
    expect(rendered.text).to include('The current generation has no organisms to suggest.')
  end

  # Issue #163 — the body line must keep the explicit [28rem] width pin
  # (spacing tokens shadow the named max-w-* scale in Tailwind v4.1).
  it 'renders the body line at the pinned [28rem] width' do
    rendered = render_inline(described_class.new(title: 'No chromosomes yet', body: 'Start by designing one.'))

    paragraph = rendered.css('p').first
    expect(paragraph['class']).to include('max-w-[28rem]')
    expect(paragraph['class']).not_to match(/max-w-(?:md|xl)/)
  end

  it 'renders a dashed hairline panel' do
    rendered = render_inline(described_class.new(title: 'Empty'))

    panel = rendered.css('.empty-state').first
    expect(panel['class']).to include('border-dashed')
    expect(panel['class']).to include('border-line')
  end

  it 'renders the action slot as a centered call to action' do
    rendered = render_inline(described_class.new(title: 'No chromosomes yet')) do |component|
      component.with_action { 'Design a chromosome' }
    end

    expect(rendered.text).to include('Design a chromosome')
  end

  it 'merges an extra class (selector stability) and an aria label' do
    rendered = render_inline(described_class.new(title: 'Empty', class_name: 'no-suggestion-available',
                                                 aria_label: 'No suggestion available'))

    panel = rendered.css('div.no-suggestion-available').first
    expect(panel).not_to be_nil
    expect(panel['aria-label']).to eq('No suggestion available')
  end

  # Issue #205 — the empty state is a box panel in the same stack (the
  # experiment page renders it directly above the configuration cards), so it
  # owns the same section rhythm the card and table carry.
  it 'carries the stacked-box rhythm itself so boxes never sit flush' do
    rendered = render_inline(described_class.new(title: 'Empty'))

    expect(rendered.css('.empty-state').first['class']).to include('mb-6')
  end

  it 'lets a container-owned layout opt out of the box rhythm' do
    rendered = render_inline(described_class.new(title: 'Empty', spacing: false))

    expect(rendered.css('.empty-state').first['class']).not_to include('mb-6')
  end
end
