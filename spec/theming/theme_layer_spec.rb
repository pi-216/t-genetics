# frozen_string_literal: true

require 'rails_helper'
require 'yaml'

# PRD-0006 (issue #117, DEV-0005) — the theme layer. `theme.css` is GENERATED
# output: derived mechanically from the locked DESIGN.md token set via the
# design-md CLI (`bundle exec rake design_theme:export`, see
# lib/tasks/design_theme.rake), never hand-edited, and imported by the real
# tailwind build chain (app/assets/stylesheets/application.tailwind.css).
# This spec is the exhaustive parity guard: EVERY color, typeface, and radius
# token in the locked DESIGN.md must exist in theme.css with its exact value.
# A failing test here means "re-export, don't hand-patch".
# rubocop:disable RSpec/DescribeClass -- no class under test: this spec guards
# the GENERATED theme.css file against drift from the locked DESIGN.md tokens.
RSpec.describe 'Theme layer' do
  # rubocop:enable RSpec/DescribeClass
  let(:design_md_path) { Rails.root.join('docs/design-sprint/ph1/DESIGN.md') }
  let(:theme_css_path) { Rails.root.join('app/assets/stylesheets/theme.css') }
  let(:tailwind_entry_path) { Rails.root.join('app/assets/stylesheets/application.tailwind.css') }
  let(:frontmatter) do
    YAML.safe_load(File.read(design_md_path).split("---\n", 3)[1], permitted_classes: [Symbol])
  end
  let(:css) { File.read(theme_css_path) }

  it 'ships the generated theme.css' do
    expect(theme_css_path).to exist
  end

  it 'is a single Tailwind v4 @theme block (generated shape, not hand-written CSS)' do
    expect(css.strip).to start_with('@theme {')
    expect(css).to end_with("}\n")
    expect(css.count('{')).to eq(1)
    expect(css.count('}')).to eq(1)
  end

  it 'declares every DESIGN.md color token with its exact value' do
    frontmatter.fetch('colors').each do |name, hex|
      expect(css).to include("--color-#{name}: #{hex.downcase}"),
                     "theme.css missing or drifted token --color-#{name} (#{hex}) from DESIGN.md"
    end
  end

  it 'declares every DESIGN.md typeface token with its exact family' do
    frontmatter.fetch('typography').each do |name, spec|
      expect(css).to include("--font-#{name}: \"#{spec.fetch('fontFamily')}\""),
                     "theme.css missing or drifted token --font-#{name} (#{spec.fetch('fontFamily')}) from DESIGN.md"
    end
  end

  it 'declares every DESIGN.md radius token with its exact value' do
    frontmatter.fetch('rounded').each do |name, value|
      expect(css).to include("--radius-#{name}: #{value}"),
                     "theme.css missing or drifted token --radius-#{name} (#{value}) from DESIGN.md"
    end
  end

  it 'is wired into the real tailwind build entry' do
    entry = File.read(tailwind_entry_path)
    expect(entry).to include('@import "tailwindcss"')
    expect(entry).to include('@import "./theme.css"')
  end
end
