# frozen_string_literal: true

require 'rails_helper'

# Web experiment workspace — org-scoped creation and browsing (PRD-0003
# DEV-0001 / issue #68). Every experiment page is scoped to the signed-in
# user's organization: cross-org chromosomes and experiments answer 404 and
# never disclose data. Creation runs the engine's Experiments::Setup command
# (name + chromosome + population size), so a created experiment carries its
# initial generation and is "pending" (evolution not yet ripe).
RSpec.describe 'Experiments workspace (web)', type: :request do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:other_org) { FactoryBot.create(:organization, name: 'Beta') }
  let!(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom', organization: org) }
  let!(:other_chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Beta-chrom', organization: other_org) }

  describe 'GET /experiments' do
    it 'requires sign-in (anonymous is redirected to the login page)' do
      get experiments_url

      expect(response).to redirect_to(login_path)
    end

    it 'lists only the signed-in organization\'s experiments' do
      sign_in_as(organization: org)
      FactoryBot.create(:experiment, name: 'Donation amounts', chromosome:,
                                     external_entity: chromosome, configuration: { 'population_size' => 20 })
      FactoryBot.create(:experiment, name: 'Beta secret', chromosome: other_chromosome,
                                     external_entity: other_chromosome)

      get experiments_url

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Donation amounts')
      expect(response.body).not_to include('Beta secret')
    end
  end

  describe 'GET /experiments/new' do
    it 'requires sign-in (anonymous is redirected to the login page)' do
      get new_experiment_url

      expect(response).to redirect_to(login_path)
    end

    it 'offers only the signed-in organization\'s chromosomes' do
      sign_in_as(organization: org)

      get new_experiment_url

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Alpha-chrom')
      expect(response.body).not_to include('Beta-chrom')
    end
  end

  describe 'POST /experiments' do
    it 'creates a named experiment with chromosome and population via the Setup command' do
      sign_in_as(organization: org)

      expect do
        post experiments_url,
             params: { experiment: { name: 'Donation amounts', chromosome_id: chromosome.id, population_size: 20 } }
      end.to change(Experiment, :count).by(1)

      experiment = Experiment.order(:id).last
      expect(experiment.name).to eq('Donation amounts')
      expect(experiment.chromosome).to eq(chromosome)
      expect(experiment.status).to eq('pending')
      expect(response).to redirect_to(experiment_url(experiment))
    end

    it 'seeds the new experiment with a population of organisms, one per organism slot' do
      sign_in_as(organization: org)

      post experiments_url,
           params: { experiment: { name: 'Donation amounts', chromosome_id: chromosome.id, population_size: 20 } }

      experiment = Experiment.order(:id).last
      expect(experiment.configuration['population_size']).to eq(20)
      expect(experiment.current_generation).to be_present
      expect(experiment.current_generation.organisms.count).to eq(20)
    end

    it 'refuses a chromosome owned by another organization (404, no row, never data)' do
      sign_in_as(organization: org)

      expect do
        post experiments_url,
             params: { experiment: { name: 'Hijack', chromosome_id: other_chromosome.id, population_size: 5 } }
      end.not_to change(Experiment, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 're-renders the form when the population size is invalid' do
      sign_in_as(organization: org)

      expect do
        post experiments_url,
             params: { experiment: { name: 'Bad', chromosome_id: chromosome.id, population_size: 0 } }
      end.not_to change(Experiment, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('Donation amounts').or include('Bad')
    end
  end

  describe 'GET /experiments/:id' do
    it 'shows the experiment with its chromosome, population, and a not-yet-ripe indicator' do
      sign_in_as(organization: org)
      experiment = FactoryBot.create(:experiment, name: 'Donation amounts', chromosome:,
                                                  external_entity: chromosome,
                                                  configuration: { 'population_size' => 20 })

      get experiment_url(experiment)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Donation amounts')
      expect(response.body).to include('Alpha-chrom')
      expect(response.body).to match(/not yet ripe/i)
    end

    it 'answers 404 for another organization\'s experiment and keeps it secret' do
      sign_in_as(organization: org)
      secret = FactoryBot.create(:experiment, name: 'Beta secret', chromosome: other_chromosome,
                                              external_entity: other_chromosome)

      get experiment_url(secret)

      expect(response).to have_http_status(:not_found)
      expect(response.body).not_to include('Beta secret')
    end
  end

  describe 'POST /experiments/:id/report' do
    let!(:experiment) do
      result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                       name: 'Donation amounts',
                                       experiment_configuration: { population_size: 20 })
      raise "Setup failed: #{result.errors.inspect}" unless result.success?

      result.experiment
    end

    # A suggestion must exist before anything can be reported — drives the real
    # loop action like the UI does.
    def request_suggestion
      post suggestion_experiment_url(experiment)
      expect(response).to have_http_status(:ok)
    end

    it 'requires sign-in (anonymous is redirected to the login page)' do
      post report_experiment_url(experiment), params: { fitness_input_value: '0.81' }

      expect(response).to redirect_to(login_path)
    end

    it 'records exactly one fitness number on the latest suggestion log and shows it' do
      sign_in_as(organization: org)
      request_suggestion
      log = PerformanceLog.order(:id).last

      expect do
        post report_experiment_url(experiment), params: { fitness_input_value: '0.81' }
      end.to change { log.reload.fitness_input_value }.from(nil).to(0.81)

      expect(response).to have_http_status(:ok)
      expect(log.reload.outcome_recorded_at).to be_present
      expect(response.body).to include('0.81')
      expect(response.body).to match(/recorded fitness/i)
    end

    it 'answers 404 for another organization\'s experiment and records nothing' do
      sign_in_as(organization: org)
      secret = Experiments::Setup.call(chromosome: other_chromosome, external_entity: other_chromosome).experiment
      secret_log_count = PerformanceLog.where(experiment_id: secret.id).count

      expect do
        post report_experiment_url(secret), params: { fitness_input_value: '0.81' }
      end.not_to change(PerformanceLog.where(experiment_id: secret.id), :count)
      expect(PerformanceLog.where(experiment_id: secret.id).count).to eq(secret_log_count)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for an unknown experiment id' do
      sign_in_as(organization: org)

      expect do
        post report_experiment_url(9_999_999), params: { fitness_input_value: '0.81' }
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 422 when no suggestion has been requested yet' do
      sign_in_as(organization: org)

      expect do
        post report_experiment_url(experiment), params: { fitness_input_value: '0.81' }
      end.not_to change(PerformanceLog, :count)
      expect(PerformanceLog.where(experiment_id: experiment.id).count).to eq(0)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/no suggestion/i)
    end

    it 'rejects a non-numeric fitness value with 422 and no change' do
      sign_in_as(organization: org)
      request_suggestion
      log = PerformanceLog.order(:id).last

      expect do
        post report_experiment_url(experiment), params: { fitness_input_value: 'high' }
      end.not_to(change { log.reload.fitness_input_value })

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to match(/number/i)
    end

    it 're-reporting updates the same suggestion log (drift A2 — audit trail on the log)' do
      sign_in_as(organization: org)
      request_suggestion
      log = PerformanceLog.order(:id).last

      post report_experiment_url(experiment), params: { fitness_input_value: '0.81' }
      expect(log.reload.fitness_input_value).to eq(0.81)

      post report_experiment_url(experiment), params: { fitness_input_value: '0.90' }

      expect(log.reload.fitness_input_value).to eq(0.90)
      expect(PerformanceLog.where(experiment_id: experiment.id).count).to eq(1)
    end
  end

  describe 'POST /experiments/:id/suggestion' do
    let!(:experiment) do
      result = Experiments::Setup.call(chromosome:, external_entity: chromosome,
                                       name: 'Donation amounts',
                                       experiment_configuration: { population_size: 20 })
      raise "Setup failed: #{result.errors.inspect}" unless result.success?

      result.experiment
    end

    it 'requires sign-in (anonymous is redirected to the login page)' do
      post suggestion_experiment_url(experiment)

      expect(response).to redirect_to(login_path)
    end

    it 'returns an organism with typed values from the current generation' do
      sign_in_as(organization: org)
      post suggestion_experiment_url(experiment)

      expect(response).to have_http_status(:ok)
      chromosome.alleles.each { |a| expect(response.body).to include(a.name) }
    end

    it 'records a performance log for the suggestion' do
      sign_in_as(organization: org)
      expect { post suggestion_experiment_url(experiment) }
        .to change(PerformanceLog, :count).by(1)

      log = PerformanceLog.order(:id).last
      expect(log.organism.generation).to eq(experiment.current_generation)
      expect(log.suggested_at).to be_present
    end

    it 'answers 404 for another organization\'s experiment and records nothing' do
      sign_in_as(organization: org)
      secret = Experiments::Setup.call(chromosome: other_chromosome, external_entity: other_chromosome).experiment

      expect do
        post suggestion_experiment_url(secret)
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:not_found)
    end

    it 'answers 404 for an unknown experiment id' do
      sign_in_as(organization: org)

      expect do
        post suggestion_experiment_url(9_999_999)
      end.not_to change(PerformanceLog, :count)

      expect(response).to have_http_status(:not_found)
    end
  end
end
