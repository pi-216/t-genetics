# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The form field wraps every labeled input:
# label above, content slot, optional hint, and inline errors below in the
# danger signal color. Inputs themselves wear the shared hairline-input
# treatment (INPUT_CLASSES) — the same class string the auth-surface request
# specs pin.
#
# Issue #141 — mobile spacing pass: the label/input/hint stack gets the kit
# vertical rhythm (space-y-2) and inputs the touch-reach padding (py-2.5 →
# ≥44px effective hit area, see --spacing-reach in theme.css).
RSpec.describe FormFieldComponent, type: :component do
  it 'pins the shared input treatment' do
    expect(described_class::INPUT_CLASSES).to include('border border-line bg-surface px-3 py-2.5 text-ink')
  end

  it 'separates label, content slot, and hint with the kit vertical rhythm' do
    rendered = render_inline(described_class.new(label: 'Fitness', hint: 'One number per organism')) do
      '<input id="fitness" type="number">'.html_safe
    end

    expect(rendered.css('section.field').first['class']).to include('space-y-2')
  end

  it 'renders the label above the content slot' do
    rendered = render_inline(described_class.new(label: 'Fitness', input_id: 'fitness_input_value')) do
      '<input id="fitness_input_value" type="number">'.html_safe
    end

    label = rendered.css('label').first
    expect(label.text).to include('Fitness')
    expect(label['for']).to eq('fitness_input_value')
    expect(rendered.css('input').first['id']).to eq('fitness_input_value')
  end

  it 'marks the label as required with a signal asterisk' do
    rendered = render_inline(described_class.new(label: 'Email', required: true)) { '<input>' }

    expect(rendered.css('label span').first['class']).to include('text-signal')
  end

  it 'renders the hint below the field' do
    rendered = render_inline(described_class.new(label: 'Name', hint: 'Monospace allows A–Z')) { '<input>' }

    expect(rendered.text).to include('Monospace allows A–Z')
  end

  it 'renders every error in the danger color below the field' do
    rendered = render_inline(described_class.new(label: 'Name', errors: ['must be present', 'is too short'])) { '<input>' }

    errors = rendered.css('p.field-error')
    expect(errors.size).to eq(2)
    errors.each do |error|
      expect(error['class']).to include('text-danger')
    end
  end
end
