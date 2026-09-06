# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'chromosomes/new' do
  before do
    assign(:chromosome, Chromosome.new(
                          name: 'MyString'
                        ))
    # The designer controller (ChromosomesController#new) always sets one
    # blank allele card; the template iterates it.
    assign(:allele_cards, [{ name: '', type: 'Float' }])
  end

  it 'renders new chromosome form' do
    render

    assert_select 'form[action=?][method=?]', chromosomes_path, 'post' do
      assert_select 'input[name=?]', 'chromosome[name]'
    end
  end
end
