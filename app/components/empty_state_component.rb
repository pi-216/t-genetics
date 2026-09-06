# frozen_string_literal: true

# Issue #133 — the component kit. The empty state is the explicit no-data
# surface (PRD-0004 convention): a dashed hairline panel with a title, a
# muted body line, and an optional centered action. Never a bare paragraph.
class EmptyStateComponent < ViewComponent::Base
  renders_one :action

  def initialize(title: nil, body: nil, class_name: nil, aria_label: nil)
    @title = title
    @body = body
    @class_name = class_name
    @aria_label = aria_label
    super()
  end

  def root_class
    ['empty-state rounded-lg border border-dashed border-line bg-surface/50 px-6 py-12 text-center', @class_name].compact.join(' ')
  end
end
