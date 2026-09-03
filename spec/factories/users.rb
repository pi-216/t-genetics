# frozen_string_literal: true

FactoryBot.define do
  factory :user, class: 'Identity::User' do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { 's3cret-password' }
  end
end
