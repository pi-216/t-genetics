# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The card is the standard dark surface
# container for internal panels: raised enough to sit on the base background,
# with a 1px hairline border (no shadows — the Lab Instrument elevation rule).
RSpec.describe CardComponent, type: :component do
  it 'renders a dark surface with a hairline border' do
    rendered = render_inline(described_class.new) { 'Body content' }

    section = rendered.css('section.card').first
    expect(section['class']).to include('bg-surface')
    expect(section['class']).to include('border-line')
    expect(rendered.text).to include('Body content')
  end

  it 'renders the title and description headers when given' do
    rendered = render_inline(described_class.new(title: 'Configuration',
                                                 description: 'The experiment dials')) { 'content' }

    expect(rendered.css('h2').text).to include('Configuration')
    expect(rendered.text).to include('The experiment dials')
  end

  it 'merges an extra class onto the surface' do
    rendered = render_inline(described_class.new(class_name: 'suggested-organism')) { 'content' }

    expect(rendered.css('section.card').first['class']).to include('suggested-organism')
  end

  it 'renders the footer slot separated by a hairline rule' do
    rendered = render_inline(described_class.new) do |component|
      component.with_content('Body')
      component.with_footer { 'Footer' }
    end

    expect(rendered.text).to include('Footer')
    expect(rendered.css('div.card-footer').first['class']).to include('border-line')
  end

  # Issue #205 — stacked boxes used to sit flush: the card rendered a
  # block-level panel with no bottom rhythm, so the index views stacked it
  # straight onto the table below (the token page's create card). The rhythm
  # belongs to the box itself (mb-6 = the DESIGN.md lg step, 24px — the step
  # PageHeaderComponent already carries), so it reaches through any wrapper.
  it 'carries the stacked-box rhythm itself so boxes never sit flush' do
    rendered = render_inline(described_class.new) { 'Body content' }

    expect(rendered.css('section.card').first['class']).to include('mb-6')
  end

  # Issue #205 — a box inside a grid/flex row (the experiment page's
  # two-column layout) is spaced by that container, so the box opts out: two
  # owners of the same rhythm is a latent doubling the moment that container
  # stops collapsing margins.
  it 'lets a container-owned layout opt out of the box rhythm' do
    rendered = render_inline(described_class.new(spacing: false)) { 'Body content' }

    expect(rendered.css('section.card').first['class']).not_to include('mb-6')
  end
end
