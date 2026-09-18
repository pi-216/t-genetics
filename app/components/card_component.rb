# frozen_string_literal: true

# Issue #133 — the component kit. The card is the standard dark surface
# container for internal panels: raised enough to sit on the base background,
# with a 1px hairline border (no shadows — the Lab Instrument elevation rule).
# Optional title/description header row and a footer slot separated by a
# hairline rule.
class CardComponent < ViewComponent::Base
  renders_one :footer

  # Issue #205 — the stacked-box rhythm (DESIGN.md lg step, 24px, the step
  # PageHeaderComponent already carries) belongs to the box itself, not to
  # whichever container happens to stack it: box panels rendered flush against
  # each other (the token page's create card touching the token table). A
  # container that owns its own rhythm — a grid/flex row — passes
  # spacing: false, so the rhythm never has two owners.
  BOX_SPACING_CLASS = 'mb-6'

  def initialize(title: nil, description: nil, pad: true, class_name: nil, spacing: true)
    @title = title
    @description = description
    @pad = pad
    @class_name = class_name
    @spacing = spacing
    super()
  end

  def root_class
    ['rounded-lg border border-line bg-surface', (@pad ? 'p-5' : nil), spacing_class,
     @class_name].compact.join(' ')
  end

  def spacing_class
    BOX_SPACING_CLASS if @spacing
  end
end
