# frozen_string_literal: true

FactoryBot.define do
  factory :org_membership, class: 'Identity::OrgMembership' do
    association :user, factory: :user
    association :organization, factory: :organization
    role { Identity::OrgMembership::MEMBER_ROLE }
  end
end
