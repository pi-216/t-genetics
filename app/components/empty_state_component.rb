# frozen_string_literal: true

# Issue #133 — the component kit. The empty state is the explicit no-data
# surface (PRD-0004 convention): a dashed hairline panel with a title, a
# muted body line, and an optional centered action. Never a bare paragraph.
class EmptyStateComponent < ViewComponent::Base
  renders_one :action

  # Issue #205 — the empty state is a box panel in the same stack as the cards
  # (the experiment page renders it directly above the configuration cards), so
  # it carries the same stacked-box rhythm (DESIGN.md lg step, 24px). A
  # container that owns the gap itself passes spacing: false.
  BOX_SPACING_CLASS = 'mb-6'

  def initialize(title: nil, body: nil, class_name: nil, aria_label: nil, spacing: true)
    @title = title
    @body = body
    @class_name = class_name
    @aria_label = aria_label
    @spacing = spacing
    super()
  end

  def root_class
    ['empty-state rounded-lg border border-dashed border-line bg-surface/50 px-6 py-12 text-center',
     spacing_class, @class_name].compact.join(' ')
  end

  def spacing_class
    BOX_SPACING_CLASS if @spacing
  end
end
