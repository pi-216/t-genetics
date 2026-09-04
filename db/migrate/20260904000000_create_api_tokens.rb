# frozen_string_literal: true

# Org-scoped API tokens for machine access (PRD-0005). Only the token DIGEST
# is ever stored — the plaintext is generated at creation, shown once, and
# never persisted. revoked_at/last_used_at are part of the PRD-0005 model
# contract (future DEV tickets enforce revocation + auth usage).
class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end