# frozen_string_literal: true

require 'rails_helper'

# Issue #207 — ChromosomesController#update must go through the command layer
# (AGENTS.md command pattern: controllers auth → validate → call command →
# render; no direct model mutation). Chromosomes::Update mirrors
# Chromosomes::Create: same GLCommand result shape, and the organization is a
# required argument — a chromosome the organization does not own fails rather
# than writing (PRD-0002 red line, enforced at every transport).
RSpec.describe Chromosomes::Update do
  let(:organization) { FactoryBot.create(:organization) }
  let(:chromosome) { FactoryBot.create(:chromosome, name: 'Original genome', organization:) }

  describe '.call' do
    context 'with a valid name' do
      it 'renames the stored chromosome' do
        described_class.call(chromosome:, organization:, name: 'Renamed genome')

        expect(chromosome.reload.name).to eq('Renamed genome')
      end

      it 'succeeds and returns the chromosome' do
        result = described_class.call(chromosome:, organization:, name: 'Renamed genome')

        expect(result.success?).to be true
        expect(result.chromosome).to eq(chromosome)
      end

      it 'leaves the chromosome alleles untouched' do
        chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)
        chromosome.reload

        described_class.call(chromosome:, organization:, name: 'Renamed genome')

        expect(chromosome.reload.alleles.map(&:name)).to eq(%w[legs])
      end
    end

    context 'with a blank name' do
      it 'fails' do
        result = described_class.call(chromosome:, organization:, name: '')

        expect(result.success?).to be false
      end

      it 'leaves the stored name unchanged' do
        described_class.call(chromosome:, organization:, name: '')

        expect(chromosome.reload.name).to eq('Original genome')
      end

      it 'surfaces the name error' do
        result = described_class.call(chromosome:, organization:, name: '')

        expect(result.errors[:name]).to be_present
      end

      # The controller re-renders the edit form from the returned record — a
      # failed command must still hand the mutated (error-carrying) chromosome
      # back, or the form renders nil.
      it 'returns the chromosome so the form can re-render it' do
        result = described_class.call(chromosome:, organization:, name: '')

        expect(result.chromosome).to eq(chromosome)
        expect(result.chromosome.errors[:name]).to be_present
      end
    end

    context 'with a chromosome owned by another organization' do
      let(:foreign_chromosome) { FactoryBot.create(:chromosome, name: 'Foreign genome') }

      it 'fails' do
        result = described_class.call(chromosome: foreign_chromosome, organization:, name: 'hijacked')

        expect(result.success?).to be false
      end

      it 'does not write the foreign chromosome' do
        described_class.call(chromosome: foreign_chromosome, organization:, name: 'hijacked')

        expect(foreign_chromosome.reload.name).to eq('Foreign genome')
      end

      it 'surfaces an ownership error' do
        result = described_class.call(chromosome: foreign_chromosome, organization:, name: 'hijacked')

        expect(result.errors[:chromosome].join).to match(/organization/i)
      end
    end
  end
end
