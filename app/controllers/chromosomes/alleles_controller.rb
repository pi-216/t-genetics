# frozen_string_literal: true

module Chromosomes
  # Issue #184 — PO ruling 2026-09-15: standard CRUD. The nested controller
  # now serves the web allele forms (new/edit, redirect-to-show on success)
  # in addition to the machine JSON contract, which is unchanged — the JSON
  # branches keep their exact statuses/bodies (pinned by
  # spec/requests/alleles_spec.rb). Web-form helpers live in
  # Chromosomes::AllelesWebForm, the machine contract in
  # Chromosomes::AllelesMachineApi.
  class AllelesController < ApplicationController
    include Chromosomes::AllelesWebForm
    include Chromosomes::AllelesMachineApi

    TYPES = %w[Integer Float Boolean Option].freeze

    before_action :require_signed_in
    before_action :set_chromosome
    before_action :set_allele, only: %i[show edit update destroy]

    def index
      alleles = @chromosome.alleles
      fresh_when(alleles)
      render json: alleles.map(&:to_hsh)
    end

    def show
      fresh_when(@allele)
      render json: @allele.to_hsh
    end

    def new
      # In-memory only: the two-phase builders (new_with_*) would persist an
      # inheritable row immediately. The web form is type-aware client-side
      # (Stimulus), defaulting to Float like the old designer's first card.
      @allele = Allele.new(inheritable: Alleles::Float.new(minimum: nil, maximum: nil))
    end

    def edit; end

    def create
      return create_json unless html_request?

      @allele = build_form_allele
      unless TYPES.include?(allele_params[:type])
        @allele.errors.add(:type, 'must be one of Integer|Float|Boolean|Option')
        return render_allele_form(:new)
      end

      missing = missing_fields_for(allele_params[:type])
      missing.each { |field| @allele.errors.add(field, 'is required') }
      return render_allele_form(:new) unless missing.empty? && @allele.inheritable.valid?

      @allele.chromosome = @chromosome
      @allele.save!
      redirect_to chromosome_url(@chromosome), notice: "Added allele #{@allele.name}."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      handle_record_errors(:new)
    end

    def update
      return update_json unless html_request?

      # Type is immutable on the web form (rendered as read-only text); the
      # server enforces it here too, exactly like the machine contract.
      if allele_params.key?(:type) && allele_params[:type] != @allele.type
        @allele.errors.add(:type, 'cannot be changed')
        return render_allele_form(:edit)
      end

      @allele.name = allele_params[:name] if allele_params.key?(:name)
      update_constraint_attributes!

      missing = missing_fields_for(@allele.type)
      missing.each { |field| @allele.errors.add(field, 'is required') }
      return render_allele_form(:edit) unless missing.empty? && @allele.inheritable.valid?

      # Delegated-type autosave only fires when the allele row is new; on
      # update the inheritable must be persisted explicitly (same as the
      # machine-path update_constraints_json!).
      @allele.inheritable.save! if @allele.type != 'Boolean' && @allele.inheritable.changed?
      @allele.save!
      redirect_to chromosome_url(@chromosome), notice: "Updated allele #{@allele.name}."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotUnique
      handle_record_errors(:edit)
    end

    def destroy
      return destroy_json unless html_request?

      name = @allele.name
      @allele.destroy!
      redirect_to chromosome_url(@chromosome), notice: "Deleted allele #{name}."
    end

    private

    def set_chromosome
      @chromosome = find_org_chromosome
      render_org_not_found unless @chromosome
    end

    def set_allele
      @allele = @chromosome.alleles.find(params[:id])
    end

    # Issue #210 — the web form posts `allele[choices]` as one comma-separated
    # string while the machine contract sends an array; permitting only
    # `choices: []` silently drops the scalar ("Unpermitted parameter") and an
    # Option allele can never be created through the browser.
    def allele_params
      @allele_params ||= params.require(:allele).permit(:name, :type, :minimum, :maximum, :choices, choices: [])
    end

    # Web forms post choices as one comma-separated string; the machine
    # contract sends an array. Normalize both to an array.
    def option_choices
      raw = allele_params[:choices]
      raw.is_a?(Array) ? raw : raw.to_s.split(',').map(&:strip).reject(&:empty?)
    end

    # Web requests carry a browser Accept starting with text/html; everything
    # else (format-less machine specs, */* clients, application/json) keeps
    # the pre-existing unconditional-JSON behavior — the machine contract is
    # pinned by alleles_spec.rb and must not depend on Accept quirks. An
    # explicit ?format=html also selects the browser branch.
    def html_request?
      request.headers['HTTP_ACCEPT'].to_s.lstrip.start_with?('text/html') ||
        request.params[:format].to_s == 'html'
    end
  end
end
