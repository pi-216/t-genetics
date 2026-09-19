# frozen_string_literal: true

module Chromosomes
  module Alleles
    # Issue #208 — the typed-allele rules every transport shares: how a type
    # name maps to an inheritable, how the browser form's comma-separated
    # choices string normalizes to an array, and which of its own type's fields
    # an allele still needs. One source for the designer command, the web form
    # and the machine JSON contract (they used to carry three copies).
    module TypedAllele
      REQUIRED_MESSAGE = 'is required'

      # The types this layer will build, and their inheritables. A literal
      # whitelist rather than a reflective lookup over the model's
      # delegated_type list — brakeman is right that a reflected class cannot be
      # proven safe, and a spec asserts this map and the model's list agree.
      # `::Alleles` is the model namespace: bare `Alleles` in this file resolves
      # to the enclosing command namespace.
      INHERITABLE_TYPES = {
        'Integer' => ::Alleles::Integer,
        'Float' => ::Alleles::Float,
        'Boolean' => ::Alleles::Boolean,
        'Option' => ::Alleles::Option
      }.freeze

      def self.types
        INHERITABLE_TYPES.keys
      end

      # An unsaved typed allele. The inheritable is built in memory and written
      # by the delegated-type autosave when the allele saves, never ahead of it
      # — an early write would strand a row whenever the allele itself fails.
      def self.build(name:, type:, minimum: nil, maximum: nil, choices: nil)
        Allele.new(name:, inheritable: build_inheritable(type, minimum:, maximum:, choices:))
      end

      # The type's own fields the record is still missing, in the machine
      # contract's order. Bounds are read off the record rather than the raw
      # params, so the browser's '' and the machine's nil agree on what
      # "missing" means and a partial update keeps the stored bound.
      #
      # `choice_list` adds Option's list: on create an absent list is a required
      # field, while on update an emptied one is the model's own
      # "must not be empty" (the machine contract reports them differently).
      def self.required_fields(allele, choice_list: false)
        case allele.type
        when 'Integer', 'Float'
          %i[minimum maximum].select { |field| allele.inheritable.public_send(field).nil? }
        when 'Boolean'
          []
        when 'Option'
          choice_list && Array(allele.inheritable.choices).empty? ? [:choices] : []
        else
          [:type]
        end
      end

      # The browser form posts one comma-separated string; the machine contract
      # sends an array. Both normalize here so a raw String can never reach the
      # choices column (Values::Option#random samples it).
      def self.normalize_choices(raw)
        return raw if raw.is_a?(Array)

        raw.to_s.split(',').map(&:strip).reject(&:empty?)
      end

      def self.build_inheritable(type, minimum:, maximum:, choices:)
        case type
        when 'Integer', 'Float' then INHERITABLE_TYPES[type].new(minimum:, maximum:)
        when 'Boolean' then INHERITABLE_TYPES[type].new
        when 'Option' then INHERITABLE_TYPES[type].new(choices: normalize_choices(choices))
        end
      end
      private_class_method :build_inheritable
    end
  end
end
