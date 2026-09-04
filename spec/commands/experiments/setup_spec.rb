# frozen_string_literal: true

require 'rails_helper'

# Experiments::Setup — the engine command that mints a new experiment with its
# initial generation and population (PRD-0003 DEV-0001 / issue #68). It is the
# single write path for experiment creation in both the web workspace and the
# machine API, so the experiment's name must always be set (explicitly, or
# falling back to the chromosome name) and the population size must be sane.
RSpec.describe Experiments::Setup do
  let!(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:chromosome) { FactoryBot.create(:chromosome_with_alleles, name: 'Alpha-chrom', organization: organization) }

  describe '#call' do
    subject(:result) do
      described_class.call(
        chromosome:,
        external_entity: chromosome,
        experiment_configuration: experiment_configuration,
        name: experiment_name
      )
    end

    let(:experiment_configuration) { { population_size: 20 } }
    let(:experiment_name) { 'Donation amounts' }

    it 'creates a pending named experiment bound to the chromosome' do
      expect(result).to be_success
      experiment = result.experiment
      expect(experiment).to be_persisted
      expect(experiment.name).to eq('Donation amounts')
      expect(experiment.chromosome).to eq(chromosome)
      expect(experiment.external_entity).to eq(chromosome)
      expect(experiment.status).to eq('pending')
    end

    it 'seeds an initial generation of population_size organisms' do
      experiment = result.experiment
      expect(experiment.configuration['population_size']).to eq(20)
      expect(experiment.current_generation).to be_present
      expect(experiment.current_generation.organisms.count).to eq(20)
    end

    it 'defaults the experiment name to the chromosome name when no name is given' do
      result = described_class.call(chromosome:, external_entity: chromosome)

      expect(result).to be_success
      expect(result.experiment.name).to eq('Alpha-chrom')
    end

    it 'rejects a non-positive population size and creates nothing' do
      result = described_class.call(
        chromosome:,
        external_entity: chromosome,
        experiment_configuration: { population_size: 0 }
      )

      expect(result).to be_failure
      expect(result.errors[:population_size]).to be_present
      expect(Experiment.count).to eq(0)
      expect(Generation.count).to eq(0)
    end

    it 'rejects an unpersisted chromosome' do
      draft = FactoryBot.build(:chromosome, organization: organization)

      result = described_class.call(chromosome: draft, external_entity: draft)

      expect(result).to be_failure
      expect(result.errors[:chromosome]).to be_present
    end
  end
end
