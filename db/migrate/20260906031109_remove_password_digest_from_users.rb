# frozen_string_literal: true

# Phase 2 of the Devise adoption (issue #118): the legacy has_secure_password
# digest is gone — Devise owns encrypted_password now. Run
# `bin/rails tgenetics:backfill_devise_passwords` between the two phases so no
# existing user loses their password.
class RemovePasswordDigestFromUsers < ActiveRecord::Migration[8.1]
  def up
    remove_column :users, :password_digest
    change_column_null :users, :encrypted_password, false
  end

  def down
    add_column :users, :password_digest, :string, null: false, default: ''
    change_column_null :users, :encrypted_password, true
  end
end
