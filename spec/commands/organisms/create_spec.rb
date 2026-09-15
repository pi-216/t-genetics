# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organisms::Create do
  describe '.call' do
    let(:generation) { instance_double(Generation, id: 1) }
    let(:chromosome) { instance_double(Chromosome) }
    let(:allele1) { instance_double(Allele, name: 'gene_a', type: 'Float') }
    let(:allele2) { instance_double(Allele, name: 'gene_b', type: 'Integer') }
    let(:alleles) { [allele1, allele2] }
    let(:new_organism) { instance_double(Organism, id: 10) }
    let(:value1_from_allele1) { instance_double(Value) }
    let(:value2_from_allele2) { instance_double(Value) }

    # Mock for the organisms association
    let(:organisms_association_proxy) { double('ActiveRecord::Associations::CollectionProxy') } # rubocop:disable RSpec/VerifiedDoubles
    # Mock for the values association on the new organism
    let(:values_association_proxy) { double('ActiveRecord::Associations::CollectionProxy') } # rubocop:disable RSpec/VerifiedDoubles

    before do
      # Allow the generation double to pass GLCommand's type check for 'requires'.
      # RSpec's instance_double doesn't automatically pass is_a?/kind_of? checks
      # against the class it's doubling. GLCommand uses these for validation.
      allow(generation).to receive(:is_a?).with(Generation).and_return(true)
      allow(generation).to receive(:kind_of?).with(Generation).and_return(true)
      # The instance_double will correctly handle other is_a?/kind_of? checks
      # (e.g., is_a?(Object) will be true, is_a?(String) will be false).

      # Allow the new_organism double to pass GLCommand's type check for 'returns'.
      allow(new_organism).to receive(:is_a?).with(Organism).and_return(true)
      allow(new_organism).to receive(:kind_of?).with(Organism).and_return(true)
      # The instance_double will correctly handle other is_a?/kind_of? checks.
      # Allow new_organism to respond to persisted? for rollback scenarios
      allow(new_organism).to receive(:persisted?).and_return(true) # Assume it's persisted if created
      allow(new_organism).to receive(:destroy) # Allow destroy for rollback

      # Stub the generation's chromosome and its alleles
      allow(generation).to receive(:chromosome).and_return(chromosome)
      allow(chromosome).to receive(:alleles).and_return(alleles)

      # Stub the creation of an organism via the association
      allow(generation).to receive(:organisms).and_return(organisms_association_proxy)
      allow(organisms_association_proxy).to receive(:create).and_return(new_organism)

      # Stub the values association on the new organism
      allow(new_organism).to receive(:values).and_return(values_association_proxy)
      allow(values_association_proxy).to receive(:<<)

      # Stub Value.new_from to return specific value instances
      allow(Value).to receive(:new_from).with(allele1).and_return(value1_from_allele1)
      allow(Value).to receive(:new_from).with(allele2).and_return(value2_from_allele2)
    end

    subject(:command_result) { described_class.call(generation:) }

    it 'succeeds' do
      expect(command_result).to be_success
    end

    it 'returns the newly created organism' do
      expect(command_result.organism).to eq(new_organism)
    end

    it 'creates an organism associated with the generation' do
      command_result
      expect(organisms_association_proxy).to have_received(:create)
    end

    it 'creates a new value for each allele in the chromosome' do
      command_result
      expect(Value).to have_received(:new_from).with(allele1)
      expect(Value).to have_received(:new_from).with(allele2)
    end

    it 'associates the new values with the created organism' do
      command_result
      expect(values_association_proxy).to have_received(:<<).with(value1_from_allele1)
      expect(values_association_proxy).to have_received(:<<).with(value2_from_allele2)
    end

    context 'when the chromosome has no alleles' do
      let(:alleles) { [] }

      it 'succeeds' do
        expect(command_result).to be_success
      end

      it 'returns the newly created organism' do
        expect(command_result.organism).to eq(new_organism)
      end

      it 'creates an organism' do
        command_result
        expect(organisms_association_proxy).to have_received(:create)
      end

      it 'does not attempt to create any values' do
        command_result
        expect(Value).not_to have_received(:new_from)
        expect(values_association_proxy).not_to have_received(:<<)
      end
    end

    context 'when organism creation fails' do
      let(:organism_with_errors) { Organism.new }

      before do
        organism_with_errors.errors.add(:base, 'Record invalid') # Simulate an error
        allow(organisms_association_proxy).to receive(:create).and_raise(ActiveRecord::RecordInvalid.new(organism_with_errors))
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'does not attempt to create values' do
        command_result
        expect(Value).not_to have_received(:new_from)
      end

      it 'propagates the error' do
        expect(command_result.errors.full_messages.to_s).to include('Record invalid')
      end
    end

    context 'when adding a value fails (e.g., Value.new_from raises an error)' do
      before do
        allow(Value).to receive(:new_from).with(allele1).and_raise(StandardError.new('Value creation failed'))
        # Ensure the organism is still "created" in the mock setup to reach the value creation step
        allow(organisms_association_proxy).to receive(:create).and_return(new_organism)
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'propagates the error' do
        expect(command_result.errors.full_messages.to_s).to include('Value creation failed')
      end

      it 'does not attempt to add subsequent values' do
        command_result
        # Value.new_from(allele1) was called and raised an error
        expect(Value).to have_received(:new_from).with(allele1).once
        # Value.new_from(allele2) should not have been called
        expect(Value).not_to have_received(:new_from).with(allele2)
        # No values should be pushed to the association
        expect(values_association_proxy).not_to have_received(:<<)
      end
    end
  end

  # Issue #166 (QA-2026-09-14 CRITICAL-1) — the core product promise is "we
  # suggest an organism to test": a fresh organism must carry a real value per
  # allele, randomized within the allele's bounds, from the moment it is born.
  # Before this fix `Value.new_from` never called `Values::*#random`, so every
  # organism was born with NULL allele data and the customer would test nothing
  # while we bred from phantom zeros.
  describe 'value assignment at birth (issue #166)', :real_db do
    # Mixed allele types (float/int/bool/option) so every valuable type gets a
    # real value. The chromosome is reloaded after adding alleles: its
    # after_initialize hook caches the (then empty) allele collection, and
    # Organisms::Create would otherwise birth values from a stale empty
    # collection.
    let(:chromosome) do
      built = FactoryBot.create(:chromosome)

      Allele.new_with_float(name: 'size', minimum: 0.5, maximum: 1.5).tap do |a|
        a.chromosome = built
        a.save!
      end
      Allele.new_with_integer(name: 'count', minimum: 2, maximum: 8).tap do |a|
        a.chromosome = built
        a.save!
      end
      Allele.new_with_boolean(name: 'enabled').tap do |a|
        a.chromosome = built
        a.save!
      end
      Allele.new_with_option(name: 'color', choices: %w[red blue]).tap do |a|
        a.chromosome = built
        a.save!
      end

      built.reload
    end

    let(:generation) { FactoryBot.create(:generation, chromosome: chromosome) }

    subject(:organism) { described_class.call(generation: generation).organism }

    it 'assigns a non-nil value within bounds for every value the organism is born with' do
      values = organism.values.includes(:allele)
      expect(values.size).to eq(4)

      by_name = values.index_by { |v| v.allele.name }
      expect(by_name['size'].data).to be_between(0.5, 1.5)
      expect(by_name['count'].data).to be_between(2, 8)
      expect(by_name['enabled'].data).to be_in([true, false])
      expect(by_name['color'].data).to be_in(%w[red blue])
    end

    it 'persists no NULL data rows for the born organism (float/integer/boolean/option)' do
      organism

      # Scoped to the born organism's own values (all four types ride on it) —
      # a table-wide `where(data: nil).count` would be brittle against leftover
      # rows in the shared test DB from aborted runs. (Not `be_present`: a
      # boolean valuable's data can legitimately be `false`, and
      # `false.present?` is false.)
      expect(organism.values.map(&:data)).not_to include(nil)
    end
  end

  describe '#rollback' do
    # Pass the command class to GLCommand::Context as its first argument
    let(:command_context) { GLCommand::Context.new(described_class) }
    subject(:command_instance) { described_class.new(command_context) }

    context 'when the organism in context is persisted' do
      let(:created_organism) { instance_double(Organism, id: 10, persisted?: true) }

      before do
        command_context.organism = created_organism # Set the organism on the context
        allow(created_organism).to receive(:destroy)
      end

      it 'destroys the created organism' do
        command_instance.rollback
        expect(created_organism).to have_received(:destroy)
      end
    end

    context 'when the organism in the context is nil' do
      before do
        command_context.organism = nil # Ensure organism is nil on the context
      end

      it 'does not attempt to destroy and does not raise error' do
        expect { command_instance.rollback }.not_to raise_error
      end
    end

    context 'when the organism in the context is not persisted' do
      let(:non_persisted_organism) { instance_double(Organism, id: nil, persisted?: false) }

      before do
        command_context.organism = non_persisted_organism # Set the non-persisted organism
        allow(non_persisted_organism).to receive(:destroy) # Should not be called
      end

      it 'does not attempt to destroy' do
        command_instance.rollback
        expect(non_persisted_organism).not_to have_received(:destroy)
      end
    end
  end
end
