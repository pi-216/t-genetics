# frozen_string_literal: true

module Identity
  # An organization — the billing boundary and data-isolation unit of the
  # product (PRD-0002). Members see only their own org's data.

  class Organization < ApplicationRecord
    has_many :org_memberships, dependent: :destroy
    has_many :users, through: :org_memberships
    has_many :chromosomes, dependent: :destroy
    has_one :invite_code, dependent: :destroy

    validates :name, presence: true, uniqueness: { case_sensitive: false }
  end
end
