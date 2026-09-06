# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Alleles::Option do
  it { is_expected.to have_one(:allele) }

  # PRD-0004 DEV-0003 (issue #79): an option allele requires a non-empty
  # choice list. The model rule is the single source of truth — the designer
  # command pre-checks it and the machine-API allele controller reaches it
  # through inheritable.valid? / update! RecordInvalid, so no path can create
  # an option allele whose choices.sample could return nil or ''.
  describe 'choice-list validation' do
    it 'is valid with non-blank choices' do
      expect(described_class.new(choices: %w[chocolate vanilla])).to be_valid
    end

    it 'is invalid with an empty array' do
      option = described_class.new(choices: [])
      expect(option).not_to be_valid
      expect(option.errors[:choices]).to include('must not be empty')
    end

    it 'is invalid with a list of only blank entries' do
      expect(described_class.new(choices: ['', nil])).not_to be_valid
    end

    it 'is invalid with nil choices' do
      expect(described_class.new(choices: nil)).not_to be_valid
    end
  end
end
