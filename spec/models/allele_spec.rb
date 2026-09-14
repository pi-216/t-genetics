# frozen_string_literal: true

require 'rails_helper'

# Finding #149: allele names were unconstrained — the DB held chromosomes
# with duplicate names (Tip Suggestions: Bold x2, Tip1 x2,...), and nothing
# rejected them at write time. Names must be unique within a chromosome
# (scoped uniqueness) while the same name on two different chromosomes stays
# legal (the designer never sees global names).
RSpec.describe Allele do
  it { is_expected.to belong_to(:chromosome) }

  it { is_expected.to validate_presence_of(:name) }

  it 'rejects a duplicate name on the same chromosome' do
    chromosome = FactoryBot.create(:chromosome)
    chromosome.alleles << described_class.new_with_float(name: 'weight', minimum: 0, maximum: 10)

    duplicate = chromosome.alleles.build(name: 'weight', inheritable: Alleles::Float.create)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:name]).to include('has already been taken')
  end

  it 'allows the same name on a different chromosome' do
    first = FactoryBot.create(:chromosome)
    first.alleles << described_class.new_with_float(name: 'weight', minimum: 0, maximum: 10)

    second = FactoryBot.create(:chromosome)
    same_name = second.alleles.build(name: 'weight', inheritable: Alleles::Float.create)

    expect(same_name).to be_valid
  end
end
