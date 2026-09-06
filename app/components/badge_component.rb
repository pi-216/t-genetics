# frozen_string_literal: true

# Issue #133 — the component kit. The badge is the small status/ripe marker:
# a short-radius (never pill) chip with a muted surface default and intent
# variants in the signal colors — experiment status, evolution ripeness,
# token/org metadata.
class BadgeComponent < ViewComponent::Base
  BASE_CLASSES = 'badge inline-flex items-center gap-1 rounded-sm px-2 py-0.5 font-data text-xs font-medium'

  VARIANTS = {
    default: 'bg-raised text-ink border border-line',
    signal: 'bg-signal/10 text-signal border border-signal/30',
    good: 'bg-good/10 text-good border border-good/30',
    danger: 'bg-danger/10 text-danger border border-danger/30',
    muted: 'text-inkMuted border border-line'
  }.freeze

  def initialize(text: nil, intent: :default, class_name: nil)
    @text = text
    @intent = intent
    @class_name = class_name
    super()
  end

  def badge_class
    [BASE_CLASSES, VARIANTS.fetch(@intent), @class_name].compact.join(' ')
  end
end
