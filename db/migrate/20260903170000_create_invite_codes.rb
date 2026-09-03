# frozen_string_literal: true

# Invite codes let new members join an organization (PRD-0002 DEV-0007 /
# issue #17). v1 = owner-generated invite CODE shared manually (no outgoing
# email — keeps the no-external-sends red line). Codes are globally unique so
# joining an org is unambiguous from the code alone (org scoping stays intact).
class CreateInviteCodes < ActiveRecord::Migration[7.1]
  def change
    create_table :invite_codes do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :code, null: false
      t.timestamps
    end
    add_index :invite_codes, :code, unique: true
  end
end
