# frozen_string_literal: true

module Inheritable
  extend ActiveSupport::Concern

  included do
    has_one :allele, as: :inheritable, touch: true, dependent: :destroy
  end

  private

  # PRD-0004 DEV-0002 (issue #78): a typed allele's bounds must not be
  # reversed — minimum <= maximum. Shared by Float and Integer (Option and
  # Boolean have no bounds columns and never declare this validation, so the
  # nil guard doubles as the no-op for them). This is the single source of
  # the rule: the designer command and the machine-API allele controller both
  # rely on it (designer validation matches the server-side rules exactly).
  def validate_minimum_not_greater_than_maximum
    return if minimum.nil? || maximum.nil?
    return unless minimum > maximum

    errors.add(:base, 'Minimum must be less than or equal to maximum')
  end
end
