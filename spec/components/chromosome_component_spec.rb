# frozen_string_literal: true

require 'rails_helper'

# PRD-0006 (issue #112, apply-pass) — component specs cover the brand
# classes (acceptance criterion). The chromosome card row renders on the
# brand surface with a hairline line border, the name in ink, and every
# allele datum in inkMuted mono tabular numerals (the shared layout body
# already applies the mono + tabular-nums default app-wide; the component
# adds the inkMuted secondary face on top).
RSpec.describe ChromosomeComponent, type: :component do
  let!(:org) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let!(:chromosome) { FactoryBot.create(:chromosome, name: 'Alpha-chrom', organization: org) }

  let(:row) { render_inline(described_class.new(chromosome: chromosome)) }

  it 'renders the card row on the brand surface with a hairline line border' do
    row_node = row.css("##{ActionView::RecordIdentifier.dom_id(chromosome)}").first

    expect(row_node).not_to be_nil
    expect(row_node['class']).to include('bg-surface')
    expect(row_node['class']).to include('border-line')
  end

  it 'renders the chromosome name in the ink text color' do
    link = row.css('a').find { |a| a.text.strip == 'Alpha-chrom' }

    expect(link).not_to be_nil
    expect(link.parent['class']).to include('text-ink')
  end

  it 'renders allele metadata in the inkMuted mono face' do
    FactoryBot.create(:allele, name: 'amount', chromosome: chromosome)

    meta_lines = row.css('p')
    expect(meta_lines.length).to be >= 2
    meta_lines.each do |p_node|
      expect(p_node['class']).to include('text-inkMuted')
      expect(p_node['class']).to include('font-mono')
    end
  end
end
