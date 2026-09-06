# frozen_string_literal: true

module Chromosomes
  # PRD-0004 DEV-0001 (issue #77) — the thin command behind the designer's
  # create flow. A designer mutation must go through a command (PRD-0004
  # red line), never a direct model write in the controller. Creates a
  # chromosome with typed alleles atomically (a failed allele rolls the whole
  # chromosome back) and org-scoped — the organization is a required argument,
  # never derived from a controller-wide default.
  class Create < GLCommand::Callable
    requires :name, organization: Identity::Organization
    allows alleles: Array # [{ name:, type:, minimum:, maximum:, choices: }]
    returns chromosome: Chromosome

    def call
      @chromosome = Chromosome.new(name:, organization:)

      ActiveRecord::Base.transaction do
        fail_command!(errors: @chromosome.errors) unless @chromosome.save

        build_alleles!
      end

      context.chromosome = @chromosome.reload
    rescue ArgumentError, ActiveRecord::RecordInvalid => e
      context.chromosome = nil
      fail_command!(errors: e.respond_to?(:record) ? e.record.errors : { alleles: [e.message] })
      raise ActiveRecord::Rollback
    rescue ActiveRecord::Rollback
      # fail_command! already populated the context errors; chromosome stays unset
    end

    def rollback
      @chromosome&.destroy if @chromosome&.persisted?
    end

    TYPES = %w[Integer Float Boolean Option].freeze

    private

    def build_alleles!
      Array(alleles).each do |attrs|
        next if attrs[:name].blank? # unused designer cards create nothing

        raise ArgumentError, "allele type must be one of Integer|Float|Boolean|Option, got: #{attrs[:type].inspect}" unless TYPES.include?(attrs[:type])

        missing = missing_fields_for(attrs[:type], attrs)
        raise ArgumentError, "allele '#{attrs[:name]}' requires: #{missing.join(', ')}" if missing.any?

        validate_bounds!(attrs)

        @chromosome.alleles << build_typed_allele(attrs)
      end
    end

    # PRD-0004 DEV-0002 (issue #78): a reversed bound is rejected with a
    # per-allele message before any inheritable is built. Mirrors the model
    # rule in Inheritable#validate_minimum_not_greater_than_maximum (Float
    # and Integer); the designer must surface the same server-side rule the
    # machine API enforces.
    def validate_bounds!(attrs)
      return unless %w[Integer Float].include?(attrs[:type])

      min = attrs[:minimum]
      max = attrs[:maximum]
      return if min.blank? || max.blank? || min.to_f <= max.to_f

      raise ArgumentError, "allele '#{attrs[:name]}': minimum (#{min}) must be less than or equal to maximum (#{max})"
    end

    # Mirrors the JSON-API guard in Chromosomes::AllelesController#missing_fields_for
    # (PRD-0004 red line: designer validation matches the server-side rules exactly).
    def missing_fields_for(type, attrs)
      missing = []
      case type
      when 'Integer', 'Float'
        missing << :minimum if attrs[:minimum].blank?
        missing << :maximum if attrs[:maximum].blank?
      when 'Option'
        missing << :choices if attrs[:choices].blank?
      when 'Boolean'
        # no constraints
      end
      missing
    end

    def build_typed_allele(attrs)
      case attrs[:type]
      when 'Integer'
        Allele.new_with_integer(name: attrs[:name],
                                minimum: attrs[:minimum], maximum: attrs[:maximum])
      when 'Float'
        Allele.new_with_float(name: attrs[:name],
                              minimum: attrs[:minimum], maximum: attrs[:maximum])
      when 'Boolean'
        Allele.new_with_boolean(name: attrs[:name])
      when 'Option'
        Allele.new_with_option(name: attrs[:name], choices: Array(attrs[:choices]))
      end
    end
  end
end
