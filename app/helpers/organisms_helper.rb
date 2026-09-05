# frozen_string_literal: true

# PRD-0004 DEV-0005 (issue #81) — the organism value viewer renders each
# value by its allele type: booleans as true/false badges, numeric types
# (float/integer) as the data plus their bounds, options as the chosen
# choice. Bounds come from the allele's inheritable record — boolean and
# option alleles have no minimum/maximum, so only the numeric types annotate
# them. The surrounding row carries data-allele/data-type attributes so the
# per-type rendering is machine-checkable.
module OrganismsHelper
  def typed_value_html(value)
    type = value.allele.type
    data = value.data
    return content_tag(:span, data, class: 'value-badge') if type == 'Boolean'

    if %w[Float Integer].include?(type)
      bounds = value.allele.inheritable
      safe_join([
                  content_tag(:span, data, class: 'value-data'),
                  content_tag(:span, "(bounds #{bounds.minimum}–#{bounds.maximum})", class: 'value-bounds')
                ], ' ')
    else
      content_tag(:span, data, class: 'value-data')
    end
  end
end
