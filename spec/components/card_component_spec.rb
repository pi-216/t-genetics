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
end
