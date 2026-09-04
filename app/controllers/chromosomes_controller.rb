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

  def create
    @chromosome = Chromosome.new(chromosome_params.merge(organization: current_organization))

    respond_to do |format|
      if @chromosome.save
        format.html { redirect_to @chromosome }
        format.json { render json: @chromosome.to_hsh, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @chromosome.errors }, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @chromosome.update(chromosome_params)
        format.html { redirect_to @chromosome }
        format.json { render json: @chromosome.to_hsh, status: :ok }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @chromosome.errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @chromosome.destroy!

    respond_to do |format|
      format.html { redirect_to chromosomes_url }
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
