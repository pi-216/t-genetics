# frozen_string_literal: true

module Chromosomes
  # Issue #184 — PO ruling 2026-09-15: standard CRUD. The nested controller
  # serves the web allele forms (new/edit, redirect-to-show on success) and the
  # machine JSON contract.
  #
  # Issue #208 — the create/update mutations run through
  # Chromosomes::Alleles::Create/Update (AGENTS.md command pattern: auth →
  # validate → call command → render). Both transports share that one command
  # path; this controller only maps the result onto a format, so the machine
  # JSON contract is unchanged (pinned by spec/requests/alleles_spec.rb) and the
  # browser form re-renders with the command's errors.
  class AllelesController < ApplicationController
    include Chromosomes::AllelesWebForm
    include Chromosomes::AllelesMachineApi

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
      # `::Alleles` is the model namespace — inside Chromosomes::Alleles it
      # resolves to the command namespace (issue #208).
      @allele = Allele.new(inheritable: ::Alleles::Float.new(minimum: nil, maximum: nil))
    end

    def edit; end

    def create
      result = Chromosomes::Alleles::Create.call(chromosome: @chromosome,
                                                 organization: current_organization,
                                                 **allele_attributes)

      respond_with_allele(result, template: :new, json_status: :created,
                                  notice: "Added allele #{result.allele.name}.")
    end

    def update
      result = Chromosomes::Alleles::Update.call(allele: @allele,
                                                 organization: current_organization,
                                                 **allele_attributes)

      respond_with_allele(result, template: :edit, json_status: :ok,
                                  notice: "Updated allele #{result.allele.name}.")
    end

    def destroy
      name = @allele.name
      @allele.destroy!
      return head :no_content unless html_request?

      redirect_to chromosome_url(@chromosome), notice: "Deleted allele #{name}."
    end

    private

    # The command result is transport-agnostic; this is the only place the
    # controller maps it onto a format.
    def respond_with_allele(result, template:, json_status:, notice:)
      @allele = result.allele
      return render_allele_json(result, json_status) unless html_request?

      return redirect_to chromosome_url(@chromosome), notice: notice if result.success?

      render_allele_form(template)
    end

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

    # Every transport hands the command the same attributes hash. A `type` key
    # that is present but null (JSON null) normalizes to a blank string: the
    # command reads a nil type as "leave the type alone", while the machine
    # contract has always rejected any provided type that differs from the
    # stored one — a null one included (pinned in spec/requests/alleles_spec.rb).
    def allele_attributes
      attributes = allele_params.to_h.symbolize_keys
      attributes[:type] = '' if attributes.key?(:type) && attributes[:type].nil?
      attributes
    end
  end
end
