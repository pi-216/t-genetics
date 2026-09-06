# frozen_string_literal: true

require 'rails_helper'

# PRD-0006 (issue #112, apply-pass) — component specs cover the brand
# classes (acceptance criterion). The page header renders its title in ink
# and its primary action with the locked button-primary spec (signal fill,
# onSignal text, mono caption metrics) — the shared amber-action-per-surface
# rule.
RSpec.describe PageheaderComponent, type: :component do
  let(:rendered) { render_inline(described_class.new(klass_name: 'Experiment')) }

  it 'renders the page title in the ink text color' do
    heading = rendered.css('h2').first

    expect(heading['class']).to include('text-ink')
  end

  it 'renders the primary action with the button-primary token utilities' do
    button = rendered.css('a').find { |a| a.text.strip == 'New Experiment' }

    expect(button).not_to be_nil
    %w[bg-signal text-onSignal font-data text-caption font-medium tracking-caption rounded-md py-3 px-5.5].each do |utility|
      expect(button['class']).to include(utility)
    end
  end
end
