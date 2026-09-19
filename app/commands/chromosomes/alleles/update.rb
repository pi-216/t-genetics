# frozen_string_literal: true

module Chromosomes
  module Alleles
    # Issue #208 — the one command behind every transport that updates an
    # allele. Same result contract as Chromosomes::Alleles::Create, and the
    # same command path the browser form and the machine JSON contract share.
    #
    # The name is not pre-checked: the model's presence rule owns it (the
    # machine contract reports a blank name as "can't be blank"). The bounds
    # are, because a bound the type requires would otherwise be written as
    # NULL — the numeric inheritables carry no presence rule of their own.
    class Update < Command
      requires :allele, organization: Identity::Organization
      allows :name, :type, :minimum, :maximum, :choices
      returns allele: Allele, error_payload: nil

      TYPE_IMMUTABLE_MESSAGE = 'cannot be changed'

      def call
        context.allele = allele

        return fail_unless_owned! unless owned_by_organization?
        return fail_on_requirements!(type: TYPE_IMMUTABLE_MESSAGE) if type_changed?

        assign_attributes!
        return fail_on_requirements!(requirement_errors) if requirement_errors.any?

        persist { save_allele! }
      end

      private

      def type_changed?
        !type.nil? && type != allele.type
      end

      def assign_attributes!
        allele.name = name unless name.nil?

        case allele.type
        when 'Integer', 'Float' then assign_bounds!
        when 'Option' then assign_choices!
        end
      end

      def assign_bounds!
        allele.inheritable.minimum = minimum unless minimum.nil?
        allele.inheritable.maximum = maximum unless maximum.nil?
      end

      def assign_choices!
        return if choices.nil?

        allele.inheritable.choices = TypedAllele.normalize_choices(choices)
      end

      def requirement_errors
        TypedAllele.required_fields(allele).index_with { TypedAllele::REQUIRED_MESSAGE }
      end

      def save_allele!
        fail_with!(allele.inheritable.errors) unless allele.inheritable.valid?

        allele.inheritable.save!
        allele.save!
      end
    end
  end
end
