# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'alleles/index' do
  before do
    assign(:alleles, FactoryBot.create_list(:allele, 2))
  end

  it 'renders the allele list on the kit table treatment' do
    render

    assert_select 'tbody tr', count: 2
    assert_select 'td', text: Regexp.new('Name'), count: 2
    assert_select 'td.font-data.tabular-nums', count: 2
  end
end
