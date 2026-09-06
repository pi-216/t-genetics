# frozen_string_literal: true

# Issue #133 — the component kit. The button is the single action control for
# internal surfaces. Variants map to the Lab Instrument tokens:
#   primary   — amber signal fill, dark onSignal text (locked button-primary)
#   secondary — transparent surface + hairline ring, ink text
#   danger    — red signal fill, dark text (contrast-safe on #FF5D5D)
#   ghost     — quiet muted text action
# It renders as a link (href:), a form-wrapping button (form_action: +
# method:, for POST loop actions), or a bare/submit button (the default).
class ButtonComponent < ViewComponent::Base
  BASE_CLASSES = 'inline-flex items-center justify-center gap-2 rounded-md font-data text-caption font-medium tracking-caption min-h-reach px-4 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-signal disabled:opacity-50 disabled:pointer-events-none'

  VARIANTS = {
    primary: 'bg-signal px-5.5 py-3 text-onSignal hover:bg-[#F7C468]',
    secondary: 'border border-line text-ink hover:bg-raised',
    danger: 'bg-danger text-onSignal hover:bg-[#E04B4B]',
    ghost: 'text-inkMuted hover:text-ink hover:bg-raised/40'
  }.freeze

  # One action control rendering as link / button_to / bare button: the
  # parameter length is the union of the three render modes, not accidental.
  # rubocop:disable Metrics/ParameterLists
  def initialize(label: nil, href: nil, variant: :secondary, type: :button,
                 name: nil, value: nil, method: nil, form_action: nil,
                 data: {}, disabled: false)
    @label = label
    @href = href
    @variant = variant
    @type = type
    @name = name
    @value = value
    @method = method
    @form_action = form_action
    @data = data
    @disabled = disabled
    super()
  end
  # rubocop:enable Metrics/ParameterLists

  def button_class
    [BASE_CLASSES, VARIANTS.fetch(@variant)].compact.join(' ')
  end

  def link?
    @href.present?
  end

  def form?
    @form_action.present?
  end
end
