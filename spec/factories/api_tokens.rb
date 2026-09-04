# frozen_string_literal: true

FactoryBot.define do
  factory :api_token, class: 'Identity::ApiToken' do
    association :organization, factory: :organization
    sequence(:name) { |n| "token-#{n}" }
    token_digest { Identity::ApiToken.digest(SecureRandom.hex(24)) }
  end
end
