# frozen_string_literal: true

require 'rails_helper'

# PRD-0006 (issue #112, apply-pass) — acceptance criterion "No stock Rails
# default palette classes (coral-*, ochre-*, olive-*, indigo-*, default
# teal-*) remain in app styles or views". The @javascript BDD scenarios
# measure computed styles on the pages they visit; this static sweep is the
# exhaustive guard over EVERY view template, ViewComponent template, and the
# tailwind build entry — a stock palette token anywhere in the product
# surface fails the apply-pass before any browser ever renders it.
STOCK_PALETTE = /\b(?:teal|coral|ochre|olive|indigo)(?:-\d+)?\b/

# rubocop:disable RSpec/DescribeClass -- no class under test: this spec
# guards the whole product surface against stock scaffold palette drift.
RSpec.describe 'Stock palette sweep' do
  let(:targets) do
    [
      Rails.root.join('app/assets/stylesheets/application.tailwind.css'),
      *Rails.root.glob('app/views/**/*.{erb,haml}'),
      *Rails.root.glob('app/components/**/*.haml'),
      *Rails.root.glob('packs/*/app/views/**/*.{erb,haml}'),
      *Rails.root.glob('packs/*/app/components/**/*.{erb,haml}')
    ]
  end

  it 'sweeps every view, component, and the app stylesheet entry' do
    # Guard against the glob silently missing a surface: the sweep must see
    # the known-shared surfaces it protects.
    expect(targets).to include(Rails.root.join('app/views/layouts/application.html.haml'))
    expect(targets).to include(Rails.root.join('app/components/chromosome_component.html.haml'))
    expect(targets).to include(Rails.root.join('packs/identity/app/views/identity/sessions/new.html.haml'))
    expect(targets.length).to be >= 15
  end

  it 'contains no stock Rails default palette classes in styles or views' do
    offenders = targets.select { |path| File.read(path).match?(STOCK_PALETTE) }

    expect(offenders).to be_empty,
                         "stock scaffold palette tokens found in: #{offenders.map(&:to_s).join(', ')}"
  end
end
# rubocop:enable RSpec/DescribeClass
