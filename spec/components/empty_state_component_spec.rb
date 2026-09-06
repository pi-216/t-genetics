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
end
