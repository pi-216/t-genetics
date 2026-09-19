# frozen_string_literal: true

module Chromosomes
  module Alleles
    # Issue #208 — what the allele commands share: the organization guard every
    # transport must pass (a chromosome outside the caller's organization is
    # never written — PRD-0002 red line) and the one place a failure is
    # recorded. `error_payload` is the body the machine JSON contract returns
    # (unchanged by this ticket, pinned in spec/requests/alleles_spec.rb);
    # `allele` carries the same messages as model errors for the form.
    class Command < ApplicationCommand
      OUT_OF_SCOPE_MESSAGE = 'does not belong to this organization'
      RECORD_ERRORS = [ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique].freeze

      private

      # A failure the command itself decided: a required field, an immutable
      # attribute, a record out of scope.
      def fail_on_requirements!(messages)
        messages.each { |field, message| Array(message).each { |text| allele.errors.add(field, text) } }
        fail_with!(messages)
      end

      # A failure the model raised — its own errors, or a plain Hash when the
      # exception carries no record.
      def fail_with!(payload)
        context.error_payload = payload
        fail_command!(errors: payload)
      end

      def fail_unless_owned!
        return if owned_by_organization?

        fail_on_requirements!(chromosome: [OUT_OF_SCOPE_MESSAGE])
      end

      def owned_by_organization?
        allele.chromosome.organization_id == organization.id
      end

      # The write, in one transaction: a failed command leaves nothing behind,
      # not even the fields that were valid on their own.
      def persist(&)
        ActiveRecord::Base.transaction(&)
      rescue *RECORD_ERRORS => e
        fail_with!(errors_for(e))
      end

      def errors_for(error)
        error.respond_to?(:record) && error.record ? error.record.errors : { base: [error.message] }
      end
    end
  end
end
