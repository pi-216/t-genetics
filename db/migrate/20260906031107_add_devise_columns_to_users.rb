# frozen_string_literal: true

# Phase 1 of the Devise adoption (issue #118): add Devise's columns next to
# the legacy has_secure_password column. Schema-only — the data move happens
# in lib/tasks/backfill_devise_passwords.rake, then RemovePasswordDigestFromUsers
# drops the legacy column (safe multi-phase change per AGENTS.md).
class AddDeviseColumnsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :encrypted_password, :string
    add_column :users, :reset_password_token, :string
    add_column :users, :reset_password_sent_at, :datetime
    add_column :users, :remember_created_at, :datetime

    add_index :users, :reset_password_token, unique: true
  end
end
