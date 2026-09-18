# frozen_string_literal: true

module Chromosomes
  # Issue #184 — the web-form half of the nested allele controller: building
  # typed alleles in memory from form params, validating the selected type's
  # fields, and surfacing errors for the kit form. Extracted from the
  # controller so both halves (web + machine JSON) stay under the rubocop
  # class-length limit. The form's view helpers (field errors, the type →
  # partial maps) live in AllelesHelper.
  module AllelesWebForm
    extend ActiveSupport::Concern

    private

    # In-memory typed allele built from the form params (never persists the
    # inheritable early — unlike the machine-path new_with_* builders, which
    # append the inheritable row on build). Save persists both via the
    # delegated-type autosave.
    def build_form_allele
      case allele_params[:type]
      when 'Integer'
        Allele.new(name: allele_params[:name], inheritable: Alleles::Integer.new(minimum: allele_params[:minimum], maximum: allele_params[:maximum]))
      when 'Float'
        Allele.new(name: allele_params[:name], inheritable: Alleles::Float.new(minimum: allele_params[:minimum], maximum: allele_params[:maximum]))
      when 'Boolean'
        Allele.new(name: allele_params[:name], inheritable: Alleles::Boolean.new)
      when 'Option'
        Allele.new(name: allele_params[:name], inheritable: Alleles::Option.new(choices: option_choices))
      else
        Allele.new(name: allele_params[:name])
      end
    end

    # PRD-0004 DEV-0002 (issue #78): the bounds rule lives on the typed
    # inheritable (Float/Integer model validation) — the form pre-checks the
    # missing fields, the inheritable validation is the source of truth.
    def missing_fields_for(type)
      missing = []
      missing << :name if allele_params[:name].blank?

      case type
      when 'Integer', 'Float'
        missing << :minimum if allele_params[:minimum].blank?
        missing << :maximum if allele_params[:maximum].blank?
      when 'Option'
        missing << :choices if option_choices.empty?
      when 'Boolean'
        # no constraints
      end

      missing
    end

    def update_constraint_attributes!
      case @allele.type
      when 'Integer', 'Float'
        attrs = allele_params.to_h.slice('minimum', 'maximum').compact
        @allele.inheritable.assign_attributes(attrs) if attrs.any?
      when 'Option'
        @allele.inheritable.assign_attributes(choices: option_choices) if allele_params.key?(:choices)
      end
    end

    def handle_record_errors(template)
      @allele.inheritable.errors.full_messages.each { |m| @allele.errors.add(:base, m) } if @allele.inheritable&.errors&.any? && @allele.errors.empty?
      render_allele_form(template)
    end

    def render_allele_form(template)
      render template, status: :unprocessable_content
    end
  end
end
