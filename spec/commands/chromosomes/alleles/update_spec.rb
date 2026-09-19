# frozen_string_literal: true

require 'rails_helper'

# Issue #208 — the one command behind every transport that updates an allele.
# Same contract as Chromosomes::Alleles::Create: the caller reads `allele` on
# success and `error_payload` on failure, and a failed update writes nothing —
# not even the fields that were individually valid.
RSpec.describe Chromosomes::Alleles::Update do
  let(:organization) { FactoryBot.create(:organization) }
  let(:chromosome) { FactoryBot.create(:chromosome, organization:) }
  let(:allele) { (chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50)).last }

  def update(**attributes)
    described_class.call(allele:, organization:, **attributes)
  end

  describe '.call' do
    context 'with new bounds' do
      it 'persists them and reports success' do
        result = update(minimum: 2, maximum: 60)

        expect(result.success?).to be true
        expect(result.allele).to eq(allele)
        expect(allele.reload.inheritable.minimum).to eq(2)
        expect(allele.reload.inheritable.maximum).to eq(60)
      end
    end

    context 'with a new name' do
      it 'renames the allele' do
        result = update(name: 'limbs')

        expect(result.success?).to be true
        expect(allele.reload.name).to eq('limbs')
      end
    end

    context 'with only one bound provided' do
      it 'leaves the other bound untouched' do
        result = update(minimum: 2)

        expect(result.success?).to be true
        expect(allele.reload.inheritable.minimum).to eq(2)
        expect(allele.reload.inheritable.maximum).to eq(50)
      end
    end

    context 'with an Option allele' do
      let(:option_allele) do
        (chromosome.alleles << Allele.new_with_option(name: 'color', choices: %w[red blue])).last
      end

      it 'replaces the choices from an array' do
        result = described_class.call(allele: option_allele, organization:, choices: %w[green yellow])

        expect(result.success?).to be true
        expect(option_allele.reload.inheritable.choices).to eq(%w[green yellow])
      end

      it 'normalizes the browser form value into an array of choices' do
        result = described_class.call(allele: option_allele, organization:, choices: 'green, yellow')

        expect(result.success?).to be true
        expect(option_allele.reload.inheritable.choices).to eq(%w[green yellow])
      end
    end

    context 'with a type that differs from the stored type' do
      it 'fails and writes nothing' do
        result = update(type: 'Float')

        expect(result.success?).to be false
        expect(result.error_payload).to eq(type: 'cannot be changed')
        expect(allele.reload.type).to eq('Integer')
      end

      it 'surfaces the error on the allele for the form' do
        result = update(type: 'Float')

        expect(result.allele.errors[:type]).to include('cannot be changed')
      end
    end

    context 'with the stored type repeated' do
      it 'accepts the payload' do
        result = update(type: 'Integer', name: 'limbs')

        expect(result.success?).to be true
        expect(allele.reload.name).to eq('limbs')
      end
    end

    context 'with bounds the wrong way round' do
      it 'fails and writes nothing' do
        result = update(minimum: 60, maximum: 2)

        expect(result.success?).to be false
        expect(result.error_payload.to_hash).to eq(base: ['Minimum must be less than or equal to maximum'])
        expect(allele.reload.inheritable.minimum).to eq(1)
        expect(allele.reload.inheritable.maximum).to eq(50)
      end

      it 'writes nothing even for the fields that were valid on their own' do
        update(name: 'limbs', minimum: 60, maximum: 2)

        expect(allele.reload.name).to eq('legs')
        expect(allele.reload.inheritable.minimum).to eq(1)
      end
    end

    context 'with a blank name' do
      it 'reports the model rule through the allele' do
        result = update(name: '')

        expect(result.success?).to be false
        expect(result.error_payload.to_hash).to eq(name: ["can't be blank"])
        expect(result.allele.errors[:name]).to include("can't be blank")
      end

      it 'leaves the stored name alone' do
        update(name: '')

        expect(allele.reload.name).to eq('legs')
      end
    end

    context 'with an Option allele and an emptied choice list' do
      let(:option_allele) do
        (chromosome.alleles << Allele.new_with_option(name: 'color', choices: %w[red blue])).last
      end

      it 'rejects the empty list and keeps the stored choices' do
        result = described_class.call(allele: option_allele, organization:, choices: [])

        expect(result.success?).to be false
        expect(result.error_payload.to_hash).to eq(choices: ['must not be empty'])
        expect(option_allele.reload.inheritable.choices).to eq(%w[red blue])
      end

      it 'rejects a list of blanks' do
        result = described_class.call(allele: option_allele, organization:, choices: ['', ' '])

        expect(result.success?).to be false
        expect(option_allele.reload.inheritable.choices).to eq(%w[red blue])
      end
    end

    context 'with a chromosome belonging to another organization' do
      let(:other_organization) { FactoryBot.create(:organization) }

      it 'fails and writes nothing' do
        result = described_class.call(allele:, organization: other_organization, name: 'limbs')

        expect(result.success?).to be false
        expect(result.errors[:chromosome].join).to match(/organization/i)
        expect(allele.reload.name).to eq('legs')
      end
    end
  end
end
