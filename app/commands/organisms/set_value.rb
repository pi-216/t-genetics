# frozen_string_literal: true

module Organisms
  class SetValue < ApplicationCommand
    requires :organism,
             :name,
             :value

    def call
      value_record = organism.values.by_name(name).first
      unless value_record
        fail_command!(errors: { name.to_sym => ["value named '#{name}' not found for organism #{organism.id}"] })
        return
      end

      valuable_object = value_record.valuable
      unless valuable_object
        # This case implies a data integrity issue if a Value record exists without its valuable part.
        fail_command!(errors: { base: ["Valuable part missing for value id #{value_record.id}, allele '#{name}'"] })
        return
      end

      valuable_object.reload # Ensure working with the latest persisted state

      return if valuable_object.update(data: value)

      fail_command!(errors: valuable_object.errors) # Propagate errors from the model
    end
  end
end
