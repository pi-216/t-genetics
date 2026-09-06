# frozen_string_literal: true

# Issue #133 — the component kit. The page header is the shared headline
# treatment for every internal surface: an optional signal kicker, the title
# in ink, an optional subtitle, an optional quiet back link, and an actions
# slot holding the surface's actions (usually the single amber action).
class PageHeaderComponent < ViewComponent::Base
  renders_one :actions

  def initialize(title:, kicker: nil, subtitle: nil, back_path: nil, back_label: 'Back')
    @title = title
    @kicker = kicker
    @subtitle = subtitle
    @back_path = back_path
    @back_label = back_label
    super()
  end
end
