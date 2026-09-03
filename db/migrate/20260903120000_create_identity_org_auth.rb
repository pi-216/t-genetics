# frozen_string_literal: true

class CreateIdentityOrgAuth < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :organizations do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :organizations, :name, unique: true

    create_table :org_memberships do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.references :organization, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end
  end
end