# frozen_string_literal: true

# Web experiment workspace (PRD-0003 DEV-0001 / issue #68). Org-scoped like
# every workspace surface: the index lists only the signed-in user's
# organization experiments (joined through their chromosome), create refuses
# chromosomes from other organizations (404, never data), and show answers 404
# for cross-org experiments. Creation runs the engine's Experiments::Setup
# command — name + chromosome + population size — so no business logic lives
# in the controller.
class ExperimentsController < ApplicationController
  before_action :require_signed_in
  before_action :set_experiment, only: %i[show suggestion report]

  def index
    @experiments = Experiment.joins(:chromosome)
                             .includes(:chromosome)
                             .where(chromosomes: { organization_id: current_organization&.id })
                             .order(:id)
  end

  def show
    load_latest_suggestion
  end

  def new
    @experiment = Experiment.new
    @chromosomes = org_chromosomes
  end

  def create
    chromosome = Chromosome.where(organization_id: current_organization&.id)
                           .find_by(id: params.dig(:experiment, :chromosome_id))
    return render_org_not_found unless chromosome

    result = Experiments::Setup.call(
      chromosome:,
      external_entity: chromosome,
      experiment_configuration: { population_size: experiment_params[:population_size].to_i },
      name: experiment_params[:name]
    )

    if result.success?
      redirect_to result.experiment
    else
      @experiment = Experiment.new(name: experiment_params[:name])
      @chromosomes = org_chromosomes
      @population_size = experiment_params[:population_size]
      @command_errors = result.errors.full_messages
      render :new, status: :unprocessable_content
    end
  end

  # PRD-0003 DEV-0003 (issue #70) — a member requests a suggestion from the
  # experiment show page. Runs the engine's Experiments::RequestSuggestion
  # command, which picks the least-tested organism of the current generation
  # and records the suggestion's PerformanceLog. Success re-renders the show
  # page with the suggested organism's typed values; a command failure (no
  # current generation / empty generation) re-renders with its errors.
  def suggestion
    result = Experiments::RequestSuggestion.call(experiment: @experiment)

    if result.success?
      @suggested_organism = result.organism
      @suggestion_log = result.performance_log
      render :show
    else
      @command_errors = result.errors.full_messages
      load_latest_suggestion
      render :show, status: :unprocessable_content
    end
  end

  # PRD-0003 DEV-0004 (issue #71) — a member reports the ONE fitness number
  # for the latest suggestion. Runs the engine's Experiments::RecordOutcome
  # command, the only fitness-bearing input in the product (never evaluated by
  # us — the customer reports it). Re-reporting updates the same suggestion
  # log (drift A2, audit trail stays on the log). No suggestion yet answers
  # 422; a non-numeric value answers 422 with a clear error.
  def report
    load_latest_suggestion
    fitness = reported_fitness_input_value
    return if performed?

    unless @suggestion_log
      @command_errors = ['No suggestion has been requested for this experiment yet']
      render :show, status: :unprocessable_content
      return
    end

    result = Experiments::RecordOutcome.call(performance_log: @suggestion_log, fitness_input_value: fitness)

    if result.success?
      render :show
    else
      @command_errors = result.errors.full_messages
      render :show, status: :unprocessable_content
    end
  end

  private

  def set_experiment
    @experiment = Experiment.joins(:chromosome)
                            .where(chromosomes: { organization_id: current_organization&.id })
                            .find_by(id: params[:id])
    render_org_not_found unless @experiment
  end

  def org_chromosomes
    Chromosome.where(organization_id: current_organization&.id).order(:id)
  end

  def experiment_params
    params.expect(experiment: %i[name chromosome_id population_size])
  end

  # The web report form sends a single bare number. A value that cannot be a
  # number answers 422 — exactly one fitness number, nothing else accepted.
  def reported_fitness_input_value
    Float(params[:fitness_input_value])
  rescue ArgumentError, TypeError
    @command_errors = ['Fitness must be a number']
    render :show, status: :unprocessable_content
    nil
  end

  # The latest suggestion log (and its organism) for the show page — the
  # suggestion the report form acts on.
  def load_latest_suggestion
    @suggestion_log = PerformanceLog.where(experiment_id: @experiment.id).order(:id).last
    @suggested_organism = @suggestion_log&.organism
  end
end
