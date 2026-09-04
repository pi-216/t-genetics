# frozen_string_literal: true

module Chromosomes
  class AllelesController < ApplicationController
    before_action :require_signed_in
    before_action :set_chromosome
    before_action :set_allele, only: %i[show update destroy]

    def index
      alleles = @chromosome.alleles
      fresh_when(alleles)
      render json: alleles.map(&:to_hsh)
    end

    def show
      fresh_when(@allele)
      render json: @allele.to_hsh
    end

    def create
      missing = missing_fields_for(typed_allele_params[:type])
      return render json: { errors: missing.index_with { 'is required' } }, status: :unprocessable_entity unless missing.empty?

      allele = build_typed_allele
      @chromosome.alleles << allele

      render json: allele.to_hsh, status: :created
    rescue ArgumentError => e
      render json: { errors: { type: e.message } }, status: :unprocessable_entity
    end

    def update
      return render json: { errors: { type: 'cannot be changed' } }, status: :unprocessable_entity if typed_allele_params.key?(:type) && typed_allele_params[:type] != @allele.type

      @allele.update!(name: typed_allele_params[:name]) if typed_allele_params[:name]
      update_constraints!

      render json: @allele.to_hsh, status: :ok
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors }, status: :unprocessable_entity
    end

    def destroy
      @allele.destroy!

      head :no_content
    end

    private

    def set_chromosome
      @chromosome = find_org_chromosome
      render_org_not_found unless @chromosome
    end

    def set_allele
      @allele = @chromosome.alleles.find(params[:id])
    end

    def typed_allele_params
      @typed_allele_params ||= params.require(:allele).permit(:name, :type, :minimum, :maximum, choices: [])
    end

    def build_typed_allele
      case typed_allele_params[:type]
      when 'Integer'
        Allele.new_with_integer(name: typed_allele_params[:name], minimum: typed_allele_params[:minimum], maximum: typed_allele_params[:maximum])
      when 'Float'
        Allele.new_with_float(name: typed_allele_params[:name], minimum: typed_allele_params[:minimum], maximum: typed_allele_params[:maximum])
      when 'Boolean'
        Allele.new_with_boolean(name: typed_allele_params[:name])
      when 'Option'
        Allele.new_with_option(name: typed_allele_params[:name], choices: typed_allele_params[:choices])
      else
        raise ArgumentError, 'must be one of Integer|Float|Boolean|Option'
      end
    end

    def missing_fields_for(type)
      missing = []
      missing << :name if typed_allele_params[:name].blank?

      case type
      when 'Integer', 'Float'
        missing << :minimum if typed_allele_params[:minimum].blank?
        missing << :maximum if typed_allele_params[:maximum].blank?
      when 'Option'
        missing << :choices if typed_allele_params[:choices].blank?
      when 'Boolean'
        # no constraints
      else
        missing << :type
      end

      missing
    end

    def update_constraints!
      case @allele.type
      when 'Integer', 'Float'
        attrs = typed_allele_params.to_h.slice('minimum', 'maximum').compact
        @allele.inheritable.update!(attrs) if attrs.any?
      when 'Option'
        return unless typed_allele_params.key?(:choices)

        @allele.inheritable.update!(choices: typed_allele_params[:choices])
      end
    end
  end
end
