# frozen_string_literal: true

# Issue #133 — the component kit. The form field wraps every labeled input:
# label above, content slot, optional hint, and inline errors below in the
# danger signal color. Inputs wear INPUT_CLASSES — the shared hairline-input
# treatment (the exact class string the auth-surface request specs pin).
class FormFieldComponent < ViewComponent::Base
  INPUT_CLASSES = 'mt-1 w-full min-h-reach rounded border border-line bg-surface px-3 py-2.5 text-ink placeholder:text-inkMuted'

  def initialize(label: nil, input_id: nil, hint: nil, errors: [], required: false)
    @label = label
    @input_id = input_id
    @hint = hint
    @errors = Array(errors)
    @required = required
    super()
  end

  def error?
    @errors.any?
  end
end
