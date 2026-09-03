# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::Organization do
  subject { FactoryBot.create(:organization) }

  describe 'associations' do
    it { is_expected.to have_many(:org_memberships).dependent(:destroy) }
    it { is_expected.to have_many(:users).through(:org_memberships) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).case_insensitive }
  end
end
