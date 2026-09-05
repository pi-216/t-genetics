# frozen_string_literal: true

# PRD-0006 — Lab Instrument brand tokens apply-pass.
#
# `app/assets/stylesheets/theme.css` is GENERATED output, never hand-edited:
# it is re-exported from the locked DESIGN.md token set
# (docs/design-sprint/ph1/DESIGN.md, founder-ruled 2026-09-04) via the
# design-md CLI, and imported by the real tailwind build chain
# (app/assets/stylesheets/application.tailwind.css). If DESIGN.md tokens
# change, re-run this task and commit the new theme.css — the token-parity
# spec (spec/theming/theme_layer_spec.rb) fails when they drift.
namespace :design_theme do
  desc 'Re-export theme.css from docs/design-sprint/ph1/DESIGN.md (design-md CLI)'
  task export: :environment do
    design_md = Rails.root.join('docs/design-sprint/ph1/DESIGN.md')
    out = Rails.root.join('app/assets/stylesheets/theme.css')

    raise "DESIGN.md not found at #{design_md}" unless design_md.exist?

    system('npx', '-y', '@google/design.md', 'export', '--format', 'css-tailwind',
           design_md.to_s, out: out.to_s) ||
      raise('design-md export failed — is Node/npx available? (npm via nvm)')

    # Normalize: the CLI omits the trailing newline; the committed file (and
    # the parity spec's generated-shape assertion) expects one. Re-exporting
    # must be byte-idempotent with what is committed.
    text = out.read
    out.write(text.end_with?("\n") ? text : "#{text}\n")

    puts "theme.css re-exported -> #{out}"
  end

  desc 'Lint the locked DESIGN.md (structural + WCAG contrast)'
  task lint: :environment do
    design_md = Rails.root.join('docs/design-sprint/ph1/DESIGN.md')
    system('npx', '-y', '@google/design.md', 'lint', design_md.to_s) ||
      raise('design-md lint failed — fix DESIGN.md before re-exporting')
  end
end
