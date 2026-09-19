# frozen_string_literal: true

module Chromosomes
  module Alleles
    # Issue #208 — the one command behind every transport that creates an
    # allele: the browser form and the workspace JSON contract (and any CLI or
    # job that follows). It builds the typed allele, applies the type's
    # required fields and the model rules, and persists it; a caller only maps
    # the result onto a format.
    #
    # A type outside the supported set is reported as a required field on
    # `:type` — the message the machine contract has always returned for it
    # (the form's type select cannot submit one).
    class Create < Command
      requires :chromosome, organization: Identity::Organization
      allows :name, :type, :minimum, :maximum, :choices
      returns allele: Allele, error_payload: nil

      def call
        context.allele = TypedAllele.build(name:, type:, minimum:, maximum:, choices:)
        allele.chromosome = chromosome

        return fail_unless_owned! unless owned_by_organization?
        return fail_on_requirements!(requirement_errors) if requirement_errors.any?

        persist { save_allele! }
      end

      private

      # Every field the type needs, name included: the machine contract reports
      # a blank name as a required field (an update leaves the name to the
      # model's presence rule, which reports it as "can't be blank").
      def requirement_errors
        missing = []
        missing << :name if allele.name.blank?
        missing.concat(TypedAllele.required_fields(allele, choice_list: true))
        missing.index_with { TypedAllele::REQUIRED_MESSAGE }
      end

      def save_allele!
        fail_with!(allele.inheritable.errors) unless allele.inheritable.valid?

        allele.save!
      end
    end
  end
end
