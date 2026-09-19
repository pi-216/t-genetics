# frozen_string_literal: true

module Chromosomes
  # PRD-0004 DEV-0001 (issue #77) — the thin command behind the designer's
  # create flow. A designer mutation must go through a command (PRD-0004
  # red line), never a direct model write in the controller. Creates a
  # chromosome with typed alleles atomically (a failed allele rolls the whole
  # chromosome back) and org-scoped — the organization is a required argument,
  # never derived from a controller-wide default.
  class Create < ApplicationCommand
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

    private

    def build_alleles!
      validate_unique_names!

      Array(alleles).each do |attrs|
        next if attrs[:name].blank? # unused designer cards create nothing

        raise ArgumentError, "allele type must be one of #{Alleles::TypedAllele.types.join('|')}, got: #{attrs[:type].inspect}" unless Alleles::TypedAllele.types.include?(attrs[:type])

        # Built in memory first (issue #208: one builder shared with the allele
        # commands) so the type's required fields are read off the record — the
        # same rule the web form and the machine contract enforce.
        allele = Alleles::TypedAllele.build(name: attrs[:name], type: attrs[:type],
                                            minimum: attrs[:minimum], maximum: attrs[:maximum], choices: attrs[:choices])

        missing = Alleles::TypedAllele.required_fields(allele)
        raise ArgumentError, "allele '#{allele.name}' requires: #{missing.join(', ')}" if missing.any?

        validate_bounds!(attrs)
        validate_choices!(attrs)

        @chromosome.alleles << allele
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

    # PRD-0004 DEV-0003 (issue #79): an option allele requires a non-empty
    # choice list — mirrors the single model rule on Alleles::Option (the
    # machine-API guard rejects a wholly missing list; the blank-only shapes
    # that slip past it — [''] — are stopped here and by the model rule).
    # The message carries the "allele '<name>':" prefix so the designer
    # renders it as an inline per-card .allele-error (DEV-0002 shape).
    def validate_choices!(attrs)
      return unless attrs[:type] == 'Option'
      return if Array(attrs[:choices]).any?(&:present?)

      raise ArgumentError, "allele '#{attrs[:name]}': choice list must not be empty"
    end

    # Finding #149: duplicate allele names within one designer payload are
    # rejected here — before any inheritable is built — with a per-allele
    # message (the "allele '<name>':" prefix the designer renders as an
    # inline per-card .allele-error, same channel as DEV-0002/DEV-0003).
    # The model-level scoped uniqueness + unique DB index back this up for
    # every other write path (append controller, API, rename).
    def validate_unique_names!
      seen = {}
      Array(alleles).each do |attrs|
        name = attrs[:name].to_s
        next if name.blank? # unused designer cards create nothing

        raise ArgumentError, "allele '#{name}': name is already used on this chromosome" if seen[name]

        seen[name] = true
      end
    end
  end
end
