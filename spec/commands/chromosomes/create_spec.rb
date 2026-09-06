# frozen_string_literal: true

require 'rails_helper'

# PRD-0004 DEV-0001 (issue #77) — Chromosomes::Create is the thin command the
# designer create flow runs (PRD-0004 red line: designer mutations go through
# commands, never direct model writes in controllers). It creates a
# chromosome with typed alleles atomically and org-scoped.
RSpec.describe Chromosomes::Create do
  let(:organization) { FactoryBot.create(:organization) }

  describe '.call' do
    context 'with mixed allele types' do
      let(:alleles) do
        [
          { name: 'weight', type: 'Float', minimum: 0, maximum: 10 },
          { name: 'limbs', type: 'Integer', minimum: 2, maximum: 4 },
          { name: 'wings', type: 'Boolean' }
        ]
      end

      it 'creates a chromosome with typed alleles under the org' do
        result = described_class.call(organization:, name: 'Mixed genome', alleles:)

        expect(result.success?).to be true
        chromosome = result.chromosome
        expect(chromosome.organization).to eq(organization)
        expect(chromosome.alleles.map(&:name)).to match_array(%w[weight limbs wings])
        expect(chromosome.alleles.map(&:type)).to match_array(%w[Float Integer Boolean])
        expect(chromosome.alleles.by_name('weight').inheritable.minimum).to eq(0.0)
        expect(chromosome.alleles.by_name('weight').inheritable.maximum).to eq(10.0)
        expect(chromosome.alleles.by_name('limbs').inheritable.minimum).to eq(2)
        expect(chromosome.alleles.by_name('wings').inheritable).to be_a(Alleles::Boolean)
      end
    end

    context 'with an option allele' do
      it 'creates the option allele with its choices' do
        result = described_class.call(organization:,
                                      name: 'Flavor genome',
                                      alleles: [{ name: 'flavor', type: 'Option', choices: %w[chocolate vanilla] }])

        expect(result.success?).to be true
        option = result.chromosome.alleles.by_name('flavor')
        expect(option.type).to eq('Option')
        expect(option.inheritable.choices).to match_array(%w[chocolate vanilla])
      end
    end

    context 'with a blank chromosome name' do
      it 'fails and creates nothing' do
        expect do
          described_class.call(organization:, name: '', alleles: [])
        end.not_to change(Chromosome, :count)
      end

      it 'surfaces the name error' do
        result = described_class.call(organization:, name: '', alleles: [])
        expect(result.success?).to be false
        expect(result.errors[:name]).to be_present
      end
    end

    context 'with an unknown allele type' do
      it 'fails and creates nothing (atomic)' do
        expect do
          described_class.call(organization:, name: 'Mixed',
                               alleles: [{ name: 'bogus', type: 'Mystery' }])
        end.not_to change(Chromosome, :count)
      end

      it 'surfaces an allele-type error' do
        result = described_class.call(organization:, name: 'Mixed',
                                      alleles: [{ name: 'bogus', type: 'Mystery' }])
        expect(result.success?).to be false
        expect(result.errors[:alleles]).to be_present
      end
    end

    context 'with a blank allele in the middle' do
      it 'skips blank allele rows (unused designer cards create nothing)' do
        result = described_class.call(organization:, name: 'Mixed',
                                      alleles: [{ name: '', type: 'Float' },
                                                { name: 'legs', type: 'Integer', minimum: 1, maximum: 2 }])

        expect(result.success?).to be true
        expect(result.chromosome.alleles.map(&:name)).to eq(%w[legs])
      end
    end

    # PRD-0004 DEV-0002 (issue #78): allele bounds are validated inline.
    context 'with a Float allele whose minimum exceeds its maximum' do
      it 'fails and creates nothing (atomic)' do
        expect do
          described_class.call(organization:, name: 'Bounded',
                               alleles: [{ name: 'weight', type: 'Float', minimum: 10, maximum: 1 }])
        end.not_to change(Chromosome, :count)
      end

      it 'surfaces a bounds error naming the allele' do
        result = described_class.call(organization:, name: 'Bounded',
                                      alleles: [{ name: 'weight', type: 'Float', minimum: 10, maximum: 1 }])

        expect(result.success?).to be false
        expect(result.errors[:alleles]).to be_present
        expect(result.errors[:alleles].join).to match(/less than or equal/i)
        expect(result.errors[:alleles].join).to include('weight')
      end
    end

    # The same rule applies to Integers (the bounds bug class, not just Float).
    context 'with an Integer allele whose minimum exceeds its maximum' do
      it 'fails and creates nothing' do
        expect do
          described_class.call(organization:, name: 'Bounded',
                               alleles: [{ name: 'limbs', type: 'Integer', minimum: 8, maximum: 2 }])
        end.not_to change(Chromosome, :count)
      end

      it 'surfaces a bounds error' do
        result = described_class.call(organization:, name: 'Bounded',
                                      alleles: [{ name: 'limbs', type: 'Integer', minimum: 8, maximum: 2 }])

        expect(result.success?).to be false
        expect(result.errors[:alleles].join).to match(/less than or equal/i)
      end
    end
  end
end
