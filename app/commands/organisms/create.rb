# frozen_string_literal: true

module Organisms
  class Create < ApplicationCommand
    requires generation: Generation
    returns organism: Organism

    def call
      context.organism = generation.organisms.create
      context.generation.chromosome.alleles.each do |allele|
        context.organism.values << Value.new_from(allele)
      end
    end

    def rollback
      # Ensure context.organism exists and is persisted before attempting to destroy
      context.organism&.destroy if context.organism&.persisted?
    end
  end
end
