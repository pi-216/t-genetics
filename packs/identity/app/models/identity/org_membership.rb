# frozen_string_literal: true

module Identity
  # Membership of a user in an organization, with a FLAT role
  # (owner or member — PRD-0002; granular permissions are ruled out).
  # v1: one org per user, enforced at both model and DB level.

  class OrgMembership < ApplicationRecord
    OWNER_ROLE = 'owner'
    MEMBER_ROLE = 'member'
    ROLES = [OWNER_ROLE, MEMBER_ROLE].freeze

    belongs_to :user
    belongs_to :organization

    validates :role, presence: true, inclusion: { in: ROLES }
    validates :user_id, uniqueness: true # v1: one org per user
  end
end
