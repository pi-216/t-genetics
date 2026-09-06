# frozen_string_literal: true

module Alleles
  class Integer < ApplicationRecord
    self.table_name = :integer_alleles

    include Inheritable

    validate :validate_minimum_not_greater_than_maximum

    def to_s
      "minimum: #{minimum}, maximum: #{maximum}"
    end

    def to_hsh
      {
        minimum: minimum,
        maximum: maximum
      }
    end
  end
end
