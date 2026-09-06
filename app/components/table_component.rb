# frozen_string_literal: true

# Issue #133 — the component kit. The table is the dense-data surface:
# full-width hairline rows, an uppercase muted header row, and a
# numeric_cell_class helper that keeps every datum in mono tabular numerals
# (the Lab Instrument rule). Empty collections render an explicit colspan
# empty state via the empty slot — never a bare list.
class TableComponent < ViewComponent::Base
  renders_one :header
  renders_one :body
  renders_one :empty

  def initialize(columns: [], empty: false, class_name: nil)
    @columns = columns
    @empty = empty
    @class_name = class_name
    super()
  end

  def root_class
    ['overflow-x-auto rounded-lg border border-line bg-surface', @class_name].compact.join(' ')
  end

  def header_cell_class
    'px-4 py-2.5 text-xs font-medium uppercase tracking-wider text-inkMuted border-b border-line whitespace-nowrap'
  end

  def cell_class
    'px-4 py-3 border-b border-line text-ink align-top'
  end

  def numeric_cell_class
    "#{cell_class} font-data tabular-nums whitespace-nowrap"
  end

  def empty_cell_class
    'px-4 py-12 text-center text-sm text-inkMuted'
  end
end
