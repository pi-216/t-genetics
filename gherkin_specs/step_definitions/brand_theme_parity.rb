# frozen_string_literal: true

require 'yaml'

# Step definitions for PRD-0006 — Lab Instrument brand tokens apply-pass.
#
# DEV-0005 (issue #117): the theme layer matches the locked token set —
# exhaustive file-level parity between the GENERATED theme.css
# (app/assets/stylesheets/theme.css) and the normative
# docs/design-sprint/ph1/DESIGN.md (founder-ruled 2026-09-04). No browser
# needed: this scenario compares files, so it is NOT @javascript.
#
# The Background step ("the application theme layer exists") is defined in
# brand_tokens.rb (DEV-0001) and is shared across all @PRD-0006 scenarios —
# do not redefine it here (cucumber raises "already defined" at load time).
#
# theme.css is generated output, never hand-edited: when DESIGN.md tokens
# change, re-export with `bundle exec rake design_theme:export`
# (lib/tasks/design_theme.rake) and commit the new file. The parity guards
# below and spec/theming/theme_layer_spec.rb fail when they drift.

When(/^I compare the application theme with the locked DESIGN\.md tokens$/) do
  @theme_css = Rails.root.join('app/assets/stylesheets/theme.css').read
  frontmatter_raw = Rails.root.join('docs/design-sprint/ph1/DESIGN.md').read.split("---\n", 3)[1]
  @design_tokens = YAML.safe_load(frontmatter_raw, permitted_classes: [Symbol])
end

Then(/^every color token matches$/) do
  @design_tokens.fetch('colors').each do |name, hex|
    expect(@theme_css).to include("--color-#{name}: #{hex.downcase}"),
                          "theme.css drifted from DESIGN.md color token --color-#{name} (#{hex})"
  end
end

Then(/^every typeface token matches$/) do
  @design_tokens.fetch('typography').each do |name, spec|
    expect(@theme_css).to include("--font-#{name}: \"#{spec.fetch('fontFamily')}\""),
                          "theme.css drifted from DESIGN.md typeface token --font-#{name} (#{spec.fetch('fontFamily')})"
  end
end

Then(/^every radius token matches$/) do
  @design_tokens.fetch('rounded').each do |name, value|
    expect(@theme_css).to include("--radius-#{name}: #{value}"),
                          "theme.css drifted from DESIGN.md radius token --radius-#{name} (#{value})"
  end
end
