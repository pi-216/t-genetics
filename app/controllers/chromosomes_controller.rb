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
    @allele_cards = [blank_allele_card]
  end

  def edit; end

  def create
    # PRD-0004 designer: an "Add allele" round trip re-renders the designer
    # with one more blank card, preserving the entered cards (server-side, no
    # JS dependency). The final submit runs the Chromosomes::Create command —
    # never a direct model write (PRD-0004 red line).
    if params[:commit] == 'Add allele'
      @chromosome = Chromosome.new(name: chromosome_params[:name])
      @allele_cards = parsed_allele_cards << blank_allele_card
      render :new
      return
    end

    result = Chromosomes::Create.call(organization: current_organization,
                                      name: chromosome_params[:name],
                                      alleles: parsed_allele_cards)

    respond_to do |format|
      if result.success?
        @chromosome = result.chromosome
        format.html { redirect_to @chromosome }
        format.json { render json: @chromosome.to_hsh, status: :created }
      else
        @chromosome = Chromosome.new(name: chromosome_params[:name])
        @chromosome.errors.merge!(result.errors)
        @allele_cards = parsed_allele_cards
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: result.errors }, status: :unprocessable_entity }
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
    params.require(:chromosome).permit(:name, alleles: %i[name type minimum maximum choices])
  end

  # The designer form posts allele cards as `chromosome[alleles][]` — an array
  # of hashes with string keys. Normalize to symbol-keyed hashes so the
  # command receives a stable shape regardless of web/API callers.
  def parsed_allele_cards
    Array(params.dig(:chromosome, :alleles)).map { |card| card.to_unsafe_h.symbolize_keys }
  end

  def blank_allele_card
    { name: '', type: 'Float' }
  end
end
