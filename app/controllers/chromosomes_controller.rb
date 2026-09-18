# frozen_string_literal: true

class ChromosomesController < ApplicationController
  before_action :require_signed_in
  before_action :set_chromosome, only: %i[show edit update destroy]

  def index
    @chromosomes = Chromosome.where(organization_id: current_organization&.id)
    fresh_when(@chromosomes)

    respond_to do |format|
      format.html
      format.json { render json: @chromosomes.map(&:to_hsh) }
    end
  end

  def show
    fresh_when(@chromosome)

    respond_to do |format|
      format.html
      format.json { render json: @chromosome.to_hsh }
    end
  end

  def new
    @chromosome = Chromosome.new
  end

  def edit; end

  # Issue #184 — PO ruling 2026-09-15: standard CRUD. The chromosome is
  # created by name only; alleles are added afterwards through their own
  # nested CRUD forms (never inline on this form).
  def create
    result = Chromosomes::Create.call(organization: current_organization,
                                      name: chromosome_params[:name])

    respond_to do |format|
      if result.success?
        @chromosome = result.chromosome
        format.html { redirect_to @chromosome, notice: "Created chromosome #{@chromosome.name}." }
        format.json { render json: @chromosome.to_hsh, status: :created }
      else
        @chromosome = Chromosome.new(name: chromosome_params[:name])
        @chromosome.errors.merge!(result.errors)
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: result.errors }, status: :unprocessable_entity }
      end
    end
  end

  # Issue #207 — the mutation goes through Chromosomes::Update (no raw model
  # write in the controller); this action only maps the command result onto a
  # format. The organization is passed explicitly — the command refuses a
  # chromosome it does not own.
  def update
    result = Chromosomes::Update.call(chromosome: @chromosome,
                                      organization: current_organization,
                                      name: chromosome_params[:name])

    respond_to do |format|
      if result.success?
        @chromosome = result.chromosome
        format.html { redirect_to @chromosome, notice: "Updated chromosome #{@chromosome.name}." }
        format.json { render json: @chromosome.to_hsh, status: :ok }
      else
        @chromosome = result.chromosome || @chromosome
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: result.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    name = @chromosome.name
    @chromosome.destroy!

    respond_to do |format|
      format.html { redirect_to chromosomes_url, notice: "Deleted chromosome #{name}." }
      format.json { head :no_content }
    end
  end

  private

  def set_chromosome
    @chromosome = find_org_chromosome
    render_org_not_found unless @chromosome
  end

  def chromosome_params
    params.require(:chromosome).permit(:name)
  end
end
