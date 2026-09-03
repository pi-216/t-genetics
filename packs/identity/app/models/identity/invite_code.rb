# frozen_string_literal: true

module Identity
  # A shareable code that lets others join an organization as members
  # (PRD-0002 DEV-0006 / issue #16). v1 invite flow is an owner-generated
  # code shared manually — no outgoing email (red line). One active code per
  # org: the generate command fetch-or-creates and the org shows its own code.
  class InviteCode < ApplicationRecord
    CODE_PREFIX = 'INVITE-'
    CODE_LENGTH = 10

    belongs_to :organization

    validates :code, presence: true, uniqueness: { case_sensitive: false }
    validates :organization_id, uniqueness: true
    before_validation { self.code = code.to_s.strip.upcase }

    def self.generate_code
      "#{CODE_PREFIX}#{SecureRandom.alphanumeric(CODE_LENGTH).upcase}"
    end
  end
end
