# frozen_string_literal: true

module Identity
  # An owner-generated invite code that lets a new user join an organization
  # as a member (PRD-0002 DEV-0007). Codes are globally unique and stored
  # normalized (uppercase, stripped) so membership lookup is unambiguous and
  # org scoping is preserved — a code joins only its own organization.
  class InviteCode < ApplicationRecord
    belongs_to :organization

    validates :code, presence: true, uniqueness: { case_sensitive: false }
    before_validation { self.code = code.to_s.strip.upcase }
  end
end
