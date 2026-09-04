# frozen_string_literal: true

class GenerationsController < ApplicationController
  before_action :require_signed_in
  before_action :set_chromosome

  def index
    generations = @chromosome.generations
    fresh_when(generations)
    render json: generations.map(&:to_hsh)
  end

  def show
    generation = @chromosome.generations.find(params[:id])
    fresh_when(generation)
    render json: generation.to_hsh
  end

  # Bootstrap the first generation.
  def create
    return render json: { errors: { generation: 'already exists for this chromosome; use procreate' } }, status: :conflict if @chromosome.generations.exists?

    generation = @chromosome.generations.create!(iteration: 1)
    20.times { Organisms::Create.call(generation:) }

    render json: generation.to_hsh, status: :created
  end

  def procreate
    parent_generation = @chromosome.generations.find(params[:id])
    offspring_generation = Generation.create(chromosome: @chromosome)
    Generations::New.call(parent_generation:, offspring_generation:)

    render json: offspring_generation.to_hsh, status: :created
  end

  private

  def set_chromosome
    @chromosome = find_org_chromosome
    render_org_not_found unless @chromosome
  end
end
