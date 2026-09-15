# frozen_string_literal: true

module Organisms
  class Crossover < ApplicationCommand
    requires :organisms

    def call
      organisms.first.chromosome.alleles.each do |allele|
        next unless rand < CROSS_OVER_RATE

        Rails.logger.debug { "Crossover of #{allele.name}" }
        values = allele.values.where(organism: organisms)

        o1 = values.first.organism
        o2 = values.last.organism
        values.first.update(organism: o2)
        values.last.update(organism: o1)
      end
    end
  end
end
