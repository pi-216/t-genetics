# frozen_string_literal: true

module Identity
  # A GAaaS user. Email+password authentication (has_secure_password/bcrypt).
  # One org per user for v1 (single membership — see PRD-0002 A2).
  class User < ApplicationRecord
    has_secure_password

    has_one :org_membership, dependent: :destroy
    has_one :organization, through: :org_membership

    # Virtual (non-persisted) form field — the org display name chosen at
    # sign-up. Persisted as Organization#name + OrgMembership by the command.

    attr_accessor :organization_name

    validates :email, presence: true,
                      uniqueness: { case_sensitive: false },
                      format: { with: URI::MailTo::EMAIL_REGEXP }
  end
end
