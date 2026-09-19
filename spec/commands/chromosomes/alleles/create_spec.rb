# frozen_string_literal: true

require 'rails_helper'

# Issue #208 — the one command behind every transport that creates an allele
# (web form, workspace JSON). It owns the typed-allele building, the
# type-required field rule, the model rules and the persistence; a caller only
# maps the result onto a format. `error_payload` is the wire-compatible error
# body the machine JSON contract has always returned, `allele` carries the same
# messages as model errors for the form.
RSpec.describe Chromosomes::Alleles::Create do
  let(:organization) { FactoryBot.create(:organization) }
  let(:chromosome) { FactoryBot.create(:chromosome, organization:) }

  def create(**attributes)
    described_class.call(chromosome:, organization:, **attributes)
  end

  describe '.call' do
    context 'with an Integer allele' do
      it 'persists the allele with its bounds on the chromosome' do
        result = create(name: 'legs', type: 'Integer', minimum: 1, maximum: 50)

        expect(result.success?).to be true
        allele = result.allele
        expect(allele).to be_persisted
        expect(allele.chromosome).to eq(chromosome)
        expect(allele.type).to eq('Integer')
        expect(allele.inheritable.minimum).to eq(1)
        expect(allele.inheritable.maximum).to eq(50)
        expect(chromosome.reload.alleles.map(&:name)).to eq(%w[legs])
      end
    end

    context 'with a Float allele' do
      it 'persists the allele with its float bounds' do
        result = create(name: 'height', type: 'Float', minimum: 1.5, maximum: 9.5)

        expect(result.success?).to be true
        expect(result.allele.inheritable.minimum).to eq(1.5)
        expect(result.allele.inheritable.maximum).to eq(9.5)
      end
    end

    context 'with a Boolean allele' do
      it 'persists the allele with no constraints' do
        result = create(name: 'flies', type: 'Boolean')

        expect(result.success?).to be true
        expect(result.allele.type).to eq('Boolean')
        expect(result.allele.inheritable).to be_a(Alleles::Boolean)
      end
    end

    context 'with an Option allele and an array of choices' do
      it 'persists the choices as given (the machine contract shape)' do
        result = create(name: 'color', type: 'Option', choices: %w[red blue])

        expect(result.success?).to be true
        expect(result.allele.inheritable.choices).to eq(%w[red blue])
      end
    end

    context 'with an Option allele and a comma-separated choices string' do
      it 'normalizes the browser form value into an array of choices' do
        result = create(name: 'color', type: 'Option', choices: 'red, blue')

        expect(result.success?).to be true
        expect(result.allele.inheritable.choices).to eq(%w[red blue])
      end
    end

    context 'with a blank name' do
      it 'fails and persists nothing' do
        expect { create(name: '', type: 'Integer', minimum: 1, maximum: 50) }
          .not_to change(Allele, :count)
      end

      it 'reports the name as a required field' do
        result = create(name: '', type: 'Integer', minimum: 1, maximum: 50)

        expect(result.success?).to be false
        expect(result.errors[:name]).to include('is required')
        expect(result.error_payload).to eq(name: 'is required')
      end
    end

    context 'with a missing constraint' do
      it 'reports every missing bound as a required field' do
        result = create(name: 'legs', type: 'Integer')

        expect(result.success?).to be false
        expect(result.error_payload).to eq(minimum: 'is required', maximum: 'is required')
      end

      it 'persists nothing' do
        expect { create(name: 'legs', type: 'Integer') }.not_to change(Allele, :count)
      end

      it 'leaves no orphaned inheritable row behind' do
        expect { create(name: 'legs', type: 'Integer') }.not_to change(Alleles::Integer, :count)
      end
    end

    context 'with a type outside the supported set' do
      it 'reports the type as required (the machine contract message)' do
        result = create(name: 'legs', type: 'Widget')

        expect(result.success?).to be false
        expect(result.error_payload).to eq(type: 'is required')
      end

      it 'persists nothing' do
        expect { create(name: 'legs', type: 'Widget') }.not_to change(Allele, :count)
      end
    end

    context 'with bounds the wrong way round' do
      it 'fails and persists nothing' do
        expect { create(name: 'legs', type: 'Integer', minimum: 50, maximum: 1) }
          .not_to change(Allele, :count)
      end

      it 'leaves no orphaned inheritable row behind' do
        expect { create(name: 'legs', type: 'Integer', minimum: 50, maximum: 1) }
          .not_to change(Alleles::Integer, :count)
      end

      it 'reports the model rule through the inheritable' do
        result = create(name: 'legs', type: 'Integer', minimum: 50, maximum: 1)

        expect(result.success?).to be false
        expect(result.allele.inheritable.errors[:base]).to include('Minimum must be less than or equal to maximum')
        expect(result.error_payload.to_hash).to eq(base: ['Minimum must be less than or equal to maximum'])
      end
    end

    context 'with an Option allele and no choices at all' do
      it 'reports the choices as a required field' do
        result = create(name: 'flavor', type: 'Option')

        expect(result.success?).to be false
        expect(result.error_payload).to eq(choices: 'is required')
      end
    end

    context 'with an Option allele whose choices are all blank' do
      it 'reports the model rule for the choice list' do
        result = create(name: 'flavor', type: 'Option', choices: [''])

        expect(result.success?).to be false
        expect(result.error_payload.to_hash).to eq(choices: ['must not be empty'])
      end

      it 'persists nothing' do
        expect { create(name: 'flavor', type: 'Option', choices: ['']) }.not_to change(Allele, :count)
      end
    end

    context 'with a name the chromosome already carries' do
      before { chromosome.alleles << Allele.new_with_integer(name: 'legs', minimum: 1, maximum: 50) }

      it 'fails and persists nothing' do
        expect { create(name: 'legs', type: 'Integer', minimum: 1, maximum: 50) }
          .not_to change(Allele, :count)
      end

      it 'reports the model rule through the allele' do
        result = create(name: 'legs', type: 'Integer', minimum: 1, maximum: 50)

        expect(result.success?).to be false
        expect(result.error_payload.to_hash).to eq(name: ['has already been taken'])
        expect(result.allele.errors[:name]).to include('has already been taken')
      end
    end

    context 'with a chromosome belonging to another organization' do
      let(:other_organization) { FactoryBot.create(:organization) }
      let(:foreign_chromosome) { FactoryBot.create(:chromosome, organization: other_organization) }

      it 'fails and persists nothing' do
        expect do
          described_class.call(chromosome: foreign_chromosome, organization:,
                               name: 'legs', type: 'Integer', minimum: 1, maximum: 50)
        end.not_to change(Allele, :count)
      end

      it 'reports the chromosome as out of scope' do
        result = described_class.call(chromosome: foreign_chromosome, organization:,
                                      name: 'legs', type: 'Integer', minimum: 1, maximum: 50)

        expect(result.success?).to be false
        expect(result.errors[:chromosome].join).to match(/organization/i)
      end
    end
  end
end
