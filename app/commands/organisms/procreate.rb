# frozen_string_literal: true

module Organisms
  class Procreate < ApplicationCommand
    requires :parents,
             target_generation: Generation
    returns :children

    def call
      errors.add(:parents, 'must be an array of two parents') unless parents.size == 2

      context.children = context.parents.map { |parent| Organisms::Clone.call!(organism: parent, target_generation:).dolly_clone }
      Organisms::Crossover.call!(organisms: context.children)
      context.children.map(&:mutate!)
    end
  end
end
