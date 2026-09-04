# frozen_string_literal: true

module Identity
  # An org-scoped machine credential (PRD-0005). The plaintext token is shown
  # exactly once at creation — only its SHA-256 digest is ever persisted.
  # Owner-only to create/revoke; org-scoped like every other domain record.
  # Authentication for /api/v1 is built on this in later DEV tickets.

  class ApiToken < ApplicationRecord
    belongs_to :organization

    validates :name, presence: true
    validates :token_digest, presence: true, uniqueness: true

    scope :active, -> { where(revoked_at: nil) }

    def self.generate_plaintext
      SecureRandom.urlsafe_base64(32)
    end

    def self.digest(plaintext)
      Digest::SHA256.hexdigest(plaintext)
    end

    def revoked?
      revoked_at.present?
    end
  end
end
