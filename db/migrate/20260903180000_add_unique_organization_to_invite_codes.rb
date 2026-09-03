# frozen_string_literal: true

# Enforces one invite code per organization at the DB level (PRD-0002
# DEV-0006 / issue #16 — owner-generated invite code, fetch-or-create).
# The v1 invite flow keeps a single stable code per org; the unique index
# makes the app-level `validates :organization_id, uniqueness: true` race-safe.
# Replaces the plain FK index (added by t.references) with a unique one.
class AddUniqueOrganizationToInviteCodes < ActiveRecord::Migration[7.1]
  def change
    remove_index :invite_codes, :organization_id
    add_index :invite_codes, :organization_id, unique: true
  end
end