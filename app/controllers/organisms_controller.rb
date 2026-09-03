# frozen_string_literal: true

class OrganismsController < ApplicationController
  before_action :set_chromosome
  before_action :set_generation
  before_action :set_organism, only: %i[show update]

  def index
    organisms = @generation.organisms
    fresh_when(organisms)
    render json: organisms.map(&:to_hsh)
  end

  def show
    fresh_when(@organism)
    render json: @organism.to_hsh
  end

  def update
    organism = @generation.organisms.find(params[:id])
    if organism.update(organism_params)
      render json: organism.to_hsh
    else
      render json: { errors: organism.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def set_chromosome
    @chromosome = find_org_chromosome
    render_org_not_found unless @chromosome
  end

  def set_generation
    @generation = @chromosome.generations.find(params[:generation_id])
  end

  def set_organism
    @organism = @generation.organisms.find(params[:id])
  end

  def organism_params
    params.require(:organism).permit(:fitness)
  end
end
