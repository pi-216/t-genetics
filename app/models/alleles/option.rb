# frozen_string_literal: true

module Alleles
  class Option < ApplicationRecord
    self.table_name = :option_alleles
    include Inheritable

    # PRD-0004 DEV-0003 (issue #79): an option allele requires a non-empty
    # choice list — a blank list (or a list of only blank entries) would let
    # Values::Option#random sample nil or '' and poison the evolution loop.
    # This is the single source of the rule: the designer command pre-checks
    # it (validate_choices!) and the machine-API allele controller routes
    # through inheritable.valid? / update! RecordInvalid.
    validate :choices_must_be_non_empty

    def crossover_algorithm
      Organisms::Crossovers::Random
    end

    def to_s
      "choices: #{choices}"
    end

    def to_hsh
      {
        choices:
      }
    end

    private

    def choices_must_be_non_empty
      return if Array(choices).any?(&:present?)

      errors.add(:choices, 'must not be empty')
    end
  end
end
