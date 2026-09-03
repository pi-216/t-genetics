# frozen_string_literal: true

# Org-scoping of chromosomes (PRD-0002 DEV-0009 / issue #19).
#
# Schema-only change: the column is intentionally nullable so pre-org legacy
# rows keep loading. The PRD calls for a non-null constraint + backfill of
# existing rows into a legacy org — that data placement decision is
# deliberately left to the product owner (bin/publish_prd founder-approval
# flow), and is tracked as a follow-up in the PR body.
class AddOrganizationToChromosomes < ActiveRecord::Migration[7.1]
  def change
    add_reference :chromosomes, :organization, null: true, foreign_key: true
  end
end