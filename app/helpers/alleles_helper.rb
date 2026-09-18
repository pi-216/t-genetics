# frozen_string_literal: true

# Issue #206 — the allele form and the chromosome show-page preview used to
# branch inline on allele.type. Each constraint-field group and each preview
# detail now lives in its own partial, and these maps are the single source of
# truth for type → markup, so the shared views only loop and render.
module AllelesHelper
  # Float and Integer share ONE numeric group: a partial per numeric type
  # would render the pinned `allele_minimum`/`allele_maximum` ids (and the
  # Stimulus `numeric` target) twice. Every group renders on every form — the
  # client-side toggle reveals the selected type's fields — so `active` (is
  # this group the allele's own type?) drives the hidden state and the value
  # lookups.
  FIELD_GROUPS = [
    { partial: 'chromosomes/alleles/numeric_fields', types: %w[Float Integer] },
    { partial: 'chromosomes/alleles/option_fields', types: %w[Option] },
    { partial: 'chromosomes/alleles/boolean_fields', types: %w[Boolean] }
  ].freeze

  PREVIEW_PARTIALS = {
    'Float' => 'chromosomes/alleles/numeric_preview',
    'Integer' => 'chromosomes/alleles/numeric_preview',
    'Boolean' => 'chromosomes/alleles/boolean_preview',
    'Option' => 'chromosomes/alleles/option_preview'
  }.freeze

  def allele_field_groups(allele)
    FIELD_GROUPS.map { |group| group.merge(active: group[:types].include?(allele.type)) }
  end

  # nil for an allele with no typed inheritable (the bare Allele.new built
  # from an unusable type param on a 422 re-render) — it has no constraint
  # detail to show.
  def allele_preview_partial(allele)
    PREVIEW_PARTIALS[allele.type]
  end

  # Field errors live on the allele (name, missing-fields) and on the typed
  # inheritable (bounds, choices) — merge both for the form.
  def field_errors(allele, field)
    allele.errors[field] + Array(allele.inheritable&.errors&.[](field))
  end
end
