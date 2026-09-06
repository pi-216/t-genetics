# frozen_string_literal: true

require 'rails_helper'

# Issue #133 — the component kit. The table is the dense-data surface:
# full-width hairline rows, an uppercase muted header row, and a
# numeric_cell_class helper that keeps every datum in mono tabular numerals
# (the Lab Instrument rule). Empty collections render an explicit colspan
# empty state, never a bare list. Rows are passed as raw markup from the
# caller; specs build them with content_tag (no html_safe).
RSpec.describe TableComponent, type: :component do
  # Slot content is raw markup from the caller; build it through the standard
  # ActionView helpers (no html_safe tagging in specs).
  def self.markup
    @markup ||= ApplicationController.helpers
  end

  def row_with(*cells)
    self.class.markup.content_tag(:tr) do
      self.class.markup.safe_join(cells.map { |cell| self.class.markup.content_tag(:td, cell) })
    end
  end

  it 'renders the column headers in the muted caption treatment' do
    rendered = render_inline(described_class.new(columns: %w[Name Status])) do |component|
      component.with_body { row_with('Alpha', 'pending') }
    end

    headers = rendered.css('th')
    expect(headers.map(&:text)).to eq(%w[Name Status])
    headers.each do |header|
      expect(header['class']).to include('text-inkMuted')
    end
  end

  it 'sits on the dark surface with a hairline border' do
    rendered = render_inline(described_class.new(columns: %w[Name])) do |component|
      component.with_body { row_with('x') }
    end

    expect(rendered.css('.table-wrap').first['class']).to include('border-line')
    expect(rendered.css('.table-wrap').first['class']).to include('bg-surface')
  end

  it 'exposes the mono tabular numeral cell treatment for numeric columns' do
    rendered = render_inline(described_class.new(columns: %w[Fitness])) do |component|
      component.with_body do
        markup = self.class.markup
        markup.content_tag(:tr) { markup.content_tag(:td, '0.81', class: component.numeric_cell_class) }
      end
    end

    cell = rendered.css('td').first
    expect(cell['class']).to include('font-data')
    expect(cell['class']).to include('tabular-nums')
  end

  it 'renders an explicit empty state with a full colspan row' do
    rendered = render_inline(described_class.new(columns: %w[Name Status], empty: true)) do |component|
      component.with_empty { 'No experiments yet' }
    end

    empty_cell = rendered.css('td').first
    expect(empty_cell['colspan']).to eq('2')
    expect(rendered.text).to include('No experiments yet')
  end
end
