# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Organisms::SetValue do
  describe '.call' do
    let(:organism_double) { instance_double(Organism, id: 1) }
    let(:allele_name) { 'gene_x' }
    let(:new_data_value) { 12.34 }

    # Mocks for the chain of calls
    let(:values_association_proxy) { double('OrganismValuesAssociation') } # rubocop:disable RSpec/VerifiedDoubles
    let(:named_scope_proxy) { double('ValuesByNameScope') } # rubocop:disable RSpec/VerifiedDoubles
    let(:value_record_double) { instance_double(Value, id: 2) } # This is the record from the 'values' table
    # The 'valuable_object_double' is the delegated object (e.g., an instance of Values::Float)
    # We use Values::Float as a representative concrete class for the instance_double.
    let(:valuable_object_double) { instance_double(Values::Float, id: 3) }
    # Errors object for the valuable_object_double.
    # Initialize with valuable_object_double so errors can be associated with it if needed by ActiveModel::Errors.
    let(:active_model_errors) { ActiveModel::Errors.new(valuable_object_double) }

    subject(:command_result) do
      described_class.call(
        organism: organism_double,
        name: allele_name,
        value: new_data_value
      )
    end

    before do
      # Mock GLCommand type check for 'organism'
      allow(organism_double).to receive(:is_a?).with(Organism).and_return(true)
      allow(organism_double).to receive(:kind_of?).with(Organism).and_return(true)

      # Stub the chain: organism.values.by_name(name).first.valuable.reload.update(...)
      allow(organism_double).to receive(:values).and_return(values_association_proxy)
      allow(values_association_proxy).to receive(:by_name).with(allele_name).and_return(named_scope_proxy)
      allow(named_scope_proxy).to receive(:first).and_return(value_record_double)

      allow(value_record_double).to receive(:valuable).and_return(valuable_object_double)
      allow(valuable_object_double).to receive(:reload).and_return(valuable_object_double) # reload typically returns self
      # Default success for update
      allow(valuable_object_double).to receive(:update).with(data: new_data_value).and_return(true)
      # Stub errors on the valuable_object_double for failure scenarios
      allow(valuable_object_double).to receive(:errors).and_return(active_model_errors)
    end

    context 'when successful' do
      it 'succeeds' do
        expect(command_result).to be_success
      end

      it 'calls the chain of methods correctly' do
        command_result
        expect(organism_double).to have_received(:values)
        expect(values_association_proxy).to have_received(:by_name).with(allele_name)
        expect(named_scope_proxy).to have_received(:first)
        expect(value_record_double).to have_received(:valuable)
        expect(valuable_object_double).to have_received(:reload)
        expect(valuable_object_double).to have_received(:update).with(data: new_data_value)
      end

      it 'returns an empty errors object' do
        expect(command_result.errors).to be_empty
      end
    end

    context 'when the Value record is not found (.first returns nil)' do
      before do
        allow(named_scope_proxy).to receive(:first).and_return(nil)
        # This will cause `nil.valuable` to raise NoMethodError in the command
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'adds the intended not-found error for the missing value' do
        expect(command_result.errors.full_messages.join).to include("value named 'gene_x' not found for organism 1")
      end
    end

    context 'when the valuable object is nil (value_record.valuable returns nil)' do
      before do
        # This scenario assumes `value_record_double.valuable` could return nil.
        allow(value_record_double).to receive(:valuable).and_return(nil)
        # This will cause `nil.reload` to raise NoMethodError in the command
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'adds the intended missing-valuable error' do
        expect(command_result.errors.full_messages.join).to include("Valuable part missing for value id 2, allele 'gene_x'")
      end
    end

    context "when valuable_object.update returns false (e.g., validation failure)" do
      before do
        allow(valuable_object_double).to receive(:update).with(data: new_data_value).and_return(false)
        # Simulate errors being added to the valuable_object_double by ActiveRecord
        active_model_errors.add(:data, 'is invalid') # Example error
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'propagates the underlying validation error from the valuable object' do
        expect(command_result.errors.full_messages.join).to include('is invalid')
      end
    end

    context 'when valuable_object.update raises an exception (e.g., database error)' do
      let(:exception_message) { 'A database error occurred' }
      before do
        allow(valuable_object_double).to receive(:update).with(data: new_data_value).and_raise(StandardError.new(exception_message))
      end

      it 'fails' do
        expect(command_result).to be_failure
      end

      it 'propagates the exception message to command errors' do
        expect(command_result.errors.full_messages.join).to include(exception_message)
      end
    end
  end
end
