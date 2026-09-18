# frozen_string_literal: true

# Issue #133 — the component kit. The form field wraps every labeled input:
# label above, content slot, optional hint, and inline errors below in the
# danger signal color. Inputs wear INPUT_CLASSES — the shared hairline-input
# treatment (the exact class string the auth-surface request specs pin).
class FormFieldComponent < ViewComponent::Base
  INPUT_CLASSES = 'mt-1 w-full min-h-reach rounded border border-line bg-surface px-3 py-2.5 text-ink placeholder:text-inkMuted'

  # Issue #204 — the inter-field rhythm (DESIGN.md "8px base grid; spacing
  # xs 4 / sm 8 / md 16") belongs to the field, not to whichever container
  # stacks the fields: a container's space-y-* never reaches through the
  # type-aware field wrappers, which left stacked fields flush. A bottom
  # margin travels with the field instead. A row that places a field beside
  # its submit button passes spacing: false — those rows bottom-align the
  # field with the button, so a bottom margin would lift it off that line.
  FIELD_SPACING_CLASS = 'mb-4'

  # Issue #204 — one keyword argument per field attribute the kit exposes;
  # the length is the component's surface, not accidental (same shape as
  # ButtonComponent's render-mode union).
  # rubocop:disable Metrics/ParameterLists
  def initialize(label: nil, input_id: nil, hint: nil, errors: [], required: false, spacing: true)
    @label = label
    @input_id = input_id
    @hint = hint
    @errors = Array(errors)
    @required = required
    @spacing = spacing
    super()
  end
  # rubocop:enable Metrics/ParameterLists

  def error?
    @errors.any?
  end

  def spacing_class
    FIELD_SPACING_CLASS if @spacing
  end
end
