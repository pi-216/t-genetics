# frozen_string_literal: true

module Identity
  # A GAaaS user. Email+password authentication via Devise (issue #118 —
  # replaces the hand-rolled has_secure_password stack). One org per user
  # for v1 (single membership — see PRD-0002 A2).
  #
  # Modules: database_authenticatable (bcrypt) · registerable · recoverable
  # (dev-delivered password reset) · rememberable · validatable (email +
  # 6..128 password, case-insensitive email via devises case_insensitive_keys).
  class User < ApplicationRecord
    devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable

    has_one :org_membership, dependent: :destroy
    has_one :organization, through: :org_membership

    # Virtual (non-persisted) form field — the org display name chosen at
    # sign-up. Persisted as Organization#name + OrgMembership by the command.

    attr_accessor :organization_name
  end
end
