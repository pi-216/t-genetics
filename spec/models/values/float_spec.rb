# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Values::Float do
  it { is_expected.to have_one(:value) }

  describe 'data read' do
    it 'never fabricates a value for missing data (issue #166 — nil stays nil)' do
      expect(described_class.new.data).to be_nil
    end
  end

  describe 'value assignment at birth' do
    # Issue #166: a freshly created organism's float values are born within
    # the allele's bounds — never NULL, never masked as 0.
    let(:chromosome) { FactoryBot.create(:chromosome) }
    let(:generation) { FactoryBot.create(:generation, chromosome:) }
    let(:organism) { Organisms::Create.call(generation:).organism }

    before do
      chromosome.alleles << Allele.new_with_float(name: 'bgm', minimum: 0.25, maximum: 0.75)
    end

    it 'assigns a randomized value within bounds at birth' do
      expect(organism.to_hsh[:bgm]).to be_between(0.25, 0.75)
    end
  end
end
