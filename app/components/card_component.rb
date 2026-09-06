# frozen_string_literal: true

# Issue #133 — the component kit. The card is the standard dark surface
# container for internal panels: raised enough to sit on the base background,
# with a 1px hairline border (no shadows — the Lab Instrument elevation rule).
# Optional title/description header row and a footer slot separated by a
# hairline rule.
class CardComponent < ViewComponent::Base
  renders_one :footer

  def initialize(title: nil, description: nil, pad: true, class_name: nil)
    @title = title
    @description = description
    @pad = pad
    @class_name = class_name
    super()
  end

  def root_class
    ['rounded-lg border border-line bg-surface', (@pad ? 'p-5' : nil), @class_name].compact.join(' ')
  end
end
