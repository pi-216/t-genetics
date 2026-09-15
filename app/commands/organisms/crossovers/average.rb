# frozen_string_literal: true

module Organisms
  module Crossovers
    class Average < ApplicationCommand
      requires :values

      def call
        avg = values.map(&:data).reduce(:+) / values.size.to_f
        values.each { |value| organism.set_value(value.name, avg) }
      end
    end
  end
end
