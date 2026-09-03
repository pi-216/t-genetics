# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Identity::InviteCode, type: :model do
  subject(:invite_code) { FactoryBot.build(:invite_code, code: 'invite-abc') }

  it 'belongs to an organization' do
    expect(invite_code.organization).to be_present
  end

  it 'normalizes the code to uppercase on save' do
    invite_code.save!
    expect(invite_code.reload.code).to eq('INVITE-ABC')
  end

  it 'requires a code' do
    expect(FactoryBot.build(:invite_code, code: '')).not_to be_valid
  end

  it 'requires a globally unique code' do
    FactoryBot.create(:invite_code, code: 'INVITE-ABC')
    expect(FactoryBot.build(:invite_code, code: 'INVITE-ABC')).not_to be_valid
  end
end
