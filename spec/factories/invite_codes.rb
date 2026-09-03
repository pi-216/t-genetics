# frozen_string_literal: true

FactoryBot.define do
  factory :invite_code, class: 'Identity::InviteCode' do
    association :organization, factory: :organization
    sequence(:code) { |n| "INVITE-#{n}" }
  end
end
