# frozen_string_literal: true

# Issue #215 — the organisms index and the organism viewer render the organisms'
# `values`, but their validators come from the organism rows; a value write
# reaches the organism through `Value belongs_to :organism, touch: true`
# (app/models/value.rb). Both actions guard with `stale?` rather than
# `fresh_when`: `fresh_when` renders the 304 itself when the request is fresh,
# so the explicit render that followed raised DoubleRenderError on every fresh
# conditional GET — a revalidating client got a 500 where a 304 was due.
class OrganismsController < ApplicationController
  before_action :require_signed_in
  before_action :set_chromosome
  before_action :set_generation
  before_action :set_organism, only: %i[show update]

  def index
    organisms = @generation.organisms
    return unless stale?(organisms)

    render json: organisms.map(&:to_hsh)
  end

  def show
    # Issue #170 — the organism viewer reads the recorded (customer-reported)
    # fitness from the PerformanceLog (across every experiment that suggested
    # this organism), not the evolution-time organism.fitness cache: a report
    # shows immediately. The ETag includes the value so a report invalidates
    # the cached page (a PerformanceLog write does not touch the organism row).
    @recorded_fitness = PerformanceLog.recorded_fitness_for(@organism)
    return unless stale?(etag: [@organism, @recorded_fitness.to_s])

    respond_to do |format|
      # PRD-0004 DEV-0005 (issue #81): HTML organism viewer — each value
      # rendered by its allele type (see views/organisms/show.html.erb).
      format.html
      # JSON shape for API/JS clients — unchanged.
      format.json { render json: @organism.to_hsh }
    end
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
