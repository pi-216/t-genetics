# frozen_string_literal: true

module Chromosomes
  # Issue #184 — the machine JSON contract for nested allele endpoints,
  # extracted from the controller so the web-form actions stay readable and
  # the class stays under the rubocop limit. The JSON behavior is pinned by
  # spec/requests/alleles_spec.rb and must not change.
  module AllelesMachineApi
    extend ActiveSupport::Concern

    private

    def create_json
      missing = missing_fields_for_json(allele_params[:type])
      return render json: { errors: missing.index_with { 'is required' } }, status: :unprocessable_content unless missing.empty?

      allele = build_typed_allele
      # PRD-0004 DEV-0002 (issue #78): the bounds rule lives on the typed
      # inheritable (Float/Integer model validation) — check it before the
      # row is attached so a reversed bound is a 422, never a 500.
      return render json: { errors: allele.inheritable.errors }, status: :unprocessable_content unless allele.inheritable.valid?

      # Explicit save — association `<<` silently swallows a validation
      # failure (returns false), which would 201 a never-persisted row.
      allele.chromosome = @chromosome
      allele.save!

      render json: allele.to_hsh, status: :created
    rescue ArgumentError => e
      render json: { errors: { type: e.message } }, status: :unprocessable_content
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique => e
      errors = e.respond_to?(:record) && e.record ? e.record.errors : { base: [e.message] }
      render json: { errors: }, status: :unprocessable_content
    end

    def update_json
      return render json: { errors: { type: 'cannot be changed' } }, status: :unprocessable_content if allele_params.key?(:type) && allele_params[:type] != @allele.type

      @allele.update!(name: allele_params[:name]) if allele_params[:name]
      update_constraints_json!

      render json: @allele.to_hsh, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors }, status: :unprocessable_content
    end

    def destroy_json
      @allele.destroy!

      head :no_content
    end

    def missing_fields_for_json(type)
      missing = []
      missing << :name if allele_params[:name].blank?

      case type
      when 'Integer', 'Float'
        missing << :minimum if allele_params[:minimum].blank?
        missing << :maximum if allele_params[:maximum].blank?
      when 'Option'
        missing << :choices if allele_params[:choices].blank?
      when 'Boolean'
        # no constraints
      else
        missing << :type
      end

      missing
    end

    def update_constraints_json!
      case @allele.type
      when 'Integer', 'Float'
        attrs = allele_params.to_h.slice('minimum', 'maximum').compact
        @allele.inheritable.update!(attrs) if attrs.any?
      when 'Option'
        return unless allele_params.key?(:choices)

        @allele.inheritable.update!(choices: allele_params[:choices])
      end
    end

    def build_typed_allele
      case allele_params[:type]
      when 'Integer'
        Allele.new_with_integer(name: allele_params[:name], minimum: allele_params[:minimum], maximum: allele_params[:maximum])
      when 'Float'
        Allele.new_with_float(name: allele_params[:name], minimum: allele_params[:minimum], maximum: allele_params[:maximum])
      when 'Boolean'
        Allele.new_with_boolean(name: allele_params[:name])
      when 'Option'
        Allele.new_with_option(name: allele_params[:name], choices: option_choices)
      else
        raise ArgumentError, 'must be one of Integer|Float|Boolean|Option'
      end
    end
  end
end
