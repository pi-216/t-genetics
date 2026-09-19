# frozen_string_literal: true

require 'rails_helper'

# Issue #208 — the typed-allele rules the designer command, the web form and
# the machine JSON contract all read.
RSpec.describe Chromosomes::Alleles::TypedAllele do
  describe '.types' do
    # The whitelist is literal (brakeman cannot prove a reflected class safe), so
    # this is the guard that it never drifts from the model's delegated_type
    # list — a type added to the model but not here would be rejected by every
    # transport.
    it 'matches the inheritable types the Allele model delegates' do
      expect(described_class.types.sort).to eq(Allele.inheritable_types.map(&:demodulize).sort)
    end

    it 'names the four supported types in the machine contract order' do
      expect(described_class.types).to eq(%w[Integer Float Boolean Option])
    end
  end

  describe '.build' do
    it 'builds an unsaved allele whose inheritable is unsaved too' do
      allele = described_class.build(name: 'legs', type: 'Integer', minimum: 1, maximum: 50)

      expect(allele).to be_new_record
      expect(allele.inheritable).to be_new_record
      expect(allele.type).to eq('Integer')
    end

    it 'builds a bare allele for a type it does not support' do
      allele = described_class.build(name: 'legs', type: 'Widget')

      expect(allele).to be_new_record
      expect(allele.inheritable).to be_nil
    end

    it 'normalizes a comma-separated choices string for an Option allele' do
      allele = described_class.build(name: 'color', type: 'Option', choices: ' red , blue ,')

      expect(allele.inheritable.choices).to eq(%w[red blue])
    end

    it 'keeps an array of choices as given' do
      allele = described_class.build(name: 'color', type: 'Option', choices: %w[red blue])

      expect(allele.inheritable.choices).to eq(%w[red blue])
    end
  end

  describe '.required_fields' do
    it 'reports a missing bound by the record, not the raw params' do
      allele = described_class.build(name: 'legs', type: 'Integer', minimum: 1)

      expect(described_class.required_fields(allele)).to eq([:maximum])
    end

    it 'reads an empty-string bound as missing' do
      allele = described_class.build(name: 'legs', type: 'Float', minimum: '', maximum: '')

      expect(described_class.required_fields(allele)).to eq(%i[minimum maximum])
    end

    it 'requires nothing for a Boolean allele' do
      allele = described_class.build(name: 'flies', type: 'Boolean')

      expect(described_class.required_fields(allele)).to be_empty
    end

    it 'does not treat an empty option list as required unless asked' do
      allele = described_class.build(name: 'color', type: 'Option', choices: [])

      expect(described_class.required_fields(allele)).to be_empty
      expect(described_class.required_fields(allele, choice_list: true)).to eq([:choices])
    end

    it 'reports an unsupported type as a required field' do
      allele = described_class.build(name: 'legs', type: 'Widget')

      expect(described_class.required_fields(allele)).to eq([:type])
    end
  end

  describe '.normalize_choices' do
    it 'returns an empty list for nothing at all' do
      expect(described_class.normalize_choices(nil)).to eq([])
    end

    it 'keeps blank entries as the model rule sees them' do
      expect(described_class.normalize_choices(['', ' '])).to eq(['', ' '])
    end
  end
end
