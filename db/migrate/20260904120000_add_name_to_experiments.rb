# frozen_string_literal: true

# Experiment naming (PRD-0003 DEV-0001 / issue #68). The web workspace creates
# experiments with a human-readable name ("Donation amounts") distinct from
# the chromosome name ("Alpha-chrom").
#
# Schema-only change: the column is intentionally nullable so pre-existing
# rows (e.g. the single legacy API-created row in dev) keep loading. New
# experiments always carry a name — the Setup command falls back to the
# chromosome name when the caller omits it, so no create path can produce a
# nameless experiment. Backfilling legacy rows is deliberately left to the
# product owner (same pattern as AddOrganizationToChromosomes).
class AddNameToExperiments < ActiveRecord::Migration[7.1]
  def change
    add_column :experiments, :name, :string
  end
end