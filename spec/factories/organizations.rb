# frozen_string_literal: true

FactoryBot.define do
  factory :organization, class: 'Identity::Organization' do
    sequence(:name) { |n| "Org #{n}" }
  end
end
