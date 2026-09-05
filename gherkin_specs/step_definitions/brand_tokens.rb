# frozen_string_literal: true

# Step definitions for PRD-0006 — Lab Instrument brand tokens apply-pass.
#
# These steps are shared by the @PRD-0006 scenarios. DEV-0001 (the shared
# layout renders the brand dark theme) is @javascript: it measures REAL
# computed styles in headless Chrome, so the assertions cannot be fooled by
# a class that is declared but never applied. The theme-layer Background
# step is driver-independent.
#
# Sabotage discipline (proven in the DEV-0001 PR):
#   - deleting app/assets/stylesheets/theme.css (or dropping --color-base
#     from it) kills the Background step;
#   - restoring the scaffold teal classes on the shared layout body/footer
#     kills all three Then steps: computed background != base, computed
#     text != ink, and the teal class scan finds classes.
# The computed-style path fail-closes if a scenario ever loses its
# @javascript tag (page.evaluate_script raises under rack_test).

Given(/^the application theme layer exists$/) do
  # The theme layer is the Tailwind v4 @theme block mechanically exported
  # from the locked DESIGN.md (docs/design-sprint/ph1/DESIGN.md) by the
  # designmd CLI — generated, never hand-edited (PRD-0006 edge case).
  theme_css = Rails.root.join('app/assets/stylesheets/theme.css')
  expect(theme_css).to exist
  expect(File.read(theme_css)).to include('--color-base')
end

When(/^I view any page$/) do
  # DEV-0001: the shared application layout is the surface under test, so
  # the public landing page (root) is the deterministic "any page".
  visit root_path
end

When(/^I view the landing page$/) do
  # DEV-0002: same deterministic surface — the landing page IS the shared
  # layout's child content, so the CTA computed styles exercise the full
  # cascade (layout body mono default + landing CTA token utilities).
  visit root_path
end

Then(/^the page background is the brand base color$/) do
  # DESIGN.md base #0B0F14 -> computed rgb(11, 15, 20). Requires a real
  # layout engine — rack_test renders no layout and would raise here.
  background = page.evaluate_script('getComputedStyle(document.body).backgroundColor')
  expect(background).to eq('rgb(11, 15, 20)')
end

Then(/^the page text is the brand ink color$/) do
  # DESIGN.md ink #E6EDF3 -> computed rgb(230, 237, 243). Real layout
  # engine required; rack_test raises, fail-closing a lost @javascript tag.
  color = page.evaluate_script('getComputedStyle(document.body).color')
  expect(color).to eq('rgb(230, 237, 243)')
end

Then(/^no scaffold teal color classes are rendered$/) do
  # Scans EVERY rendered element's class attribute (visible and hidden) for
  # the Rails scaffold's teal palette — one teal class anywhere is a fail.
  teal_classes = page.all('*', visible: false).filter_map { |el| el[:class].to_s }
                     .select { |cls| cls.include?('teal') }
  expect(teal_classes).to be_empty
end

# ---- DEV-0002: the landing primary CTA is the amber signal button ----

# The primary call to action is the single "Start free" link on the landing
# page (register_path). DESIGN.md button-primary: signal fill, onSignal
# text, caption metrics in the mono default face (see the feature header
# drift flag — the founder-ruled Direction A moodboard sets the CTA in the
# mono face; DESIGN.md button-primary.typography references caption).

def landing_primary_cta
  page.find('a.landing-cta-link', text: 'Start free')
end

Then(/^the primary call to action has the signal background$/) do
  # DESIGN.md colors.signal #F5B64A -> computed rgb(245, 182, 74).
  background = landing_primary_cta.evaluate_script('getComputedStyle(this).backgroundColor')
  expect(background).to eq('rgb(245, 182, 74)')
end

Then(/^the primary call to action has onSignal text$/) do
  # DESIGN.md colors.onSignal #1A1205 -> computed rgb(26, 18, 5).
  color = landing_primary_cta.evaluate_script('getComputedStyle(this).color')
  expect(color).to eq('rgb(26, 18, 5)')
end

Then(/^the primary call to action renders in the mono caption face$/) do
  # Caption METRICS from DESIGN.md typography.caption (0.8125rem / 500 /
  # +0.08em letter-spacing) applied in the layout's mono default face.
  # Computed at a 16px root: size 13px, letter-spacing 1.04px (0.08em * 13).
  style = landing_primary_cta.evaluate_script(<<~JS)
    (() => {
      const s = getComputedStyle(this);
      return { family: s.fontFamily, size: s.fontSize, weight: s.fontWeight, spacing: s.letterSpacing };
    })()
  JS
  expect(style['family']).to match(/mono|Menlo|Consolas|Monaco/i)
  expect(style['size']).to eq('13px')
  expect(style['weight']).to eq('500')
  expect(style['spacing']).to eq('1.04px')
end

# ---- DEV-0003: the landing page declares the brand structure ----

# The landing page's section kickers are the small uppercase labels above the
# content sections (design-sprint skeleton .hero .k / moodboard .A .kicker).
# Per the feature-header drift flag they carry the signal color with caption
# METRICS in the mono face: computed color rgb(245, 182, 74) is the binding
# assertion; the face/metrics are the design resolution, not asserted here.

Then(/^the section kickers render in the signal color$/) do
  kickers = page.all('.landing-kicker')
  expect(kickers.length).to be >= 1
  kickers.each do |kicker|
    color = kicker.evaluate_script('getComputedStyle(this).color')
    expect(color).to eq('rgb(245, 182, 74)')
  end
end

Then(/^the landing hero renders the display typeface on the base background$/) do
  # DESIGN.md typography.display: Inter 700 3rem -0.02em computed at a 16px
  # root: family "Inter, system-ui, sans-serif", 48px, 700, -0.96px spacing.
  # The display face lives on the hero's h1 title; the hero section itself
  # must sit on the base background (rgb(11, 15, 20)).
  hero = page.find('.landing-hero')
  title = hero.find('h1')

  background = hero.evaluate_script('getComputedStyle(this).backgroundColor')
  expect(background).to eq('rgb(11, 15, 20)')

  style = title.evaluate_script(<<~JS)
    (() => {
      const s = getComputedStyle(this);
      return { family: s.fontFamily, size: s.fontSize, weight: s.fontWeight, spacing: s.letterSpacing };
    })()
  JS
  expect(style['family']).to match(/Inter|sans-serif/i)
  expect(style['size']).to eq('48px')
  expect(style['weight']).to eq('700')
  expect(style['spacing']).to eq('-0.96px')
end

# ---- DEV-0004: numeric data renders in mono tabular numerals ----

# DESIGN.md typography.data is normative: "every number, id, and metric —
# tabular, aligned, instrument-grade" and its Do/Don't: "Do use mono tabular
# numerals for EVERY datum (fitness, ids, generations)." The shared layout's
# body already applies the mono face app-wide (font-mono — DESIGN.md data
# fontFamily); the binding behavior under test is the tabular numeral feature
# (font-variant-numeric: tabular-nums), asserted on EVERY rendered element
# whose OWN text payload contains a digit — fitness values, ids, generations,
# timestamps, counts. The experiment show page is the app's densest numeric
# surface; the loop-driven Given above guarantees it is populated.
#
# Requires a real layout engine (@javascript): rack_test renders no layout
# and evaluate_script raises — the step fails closed if the tag is lost.

def numeric_data_elements
  page.evaluate_script(<<~'JS')
    (() => {
      const numeric = [];
      for (const el of document.querySelectorAll('body *')) {
        if (['SCRIPT', 'STYLE', 'NOSCRIPT'].includes(el.tagName)) continue;
        const ownText = Array.from(el.childNodes)
          .filter((n) => n.nodeType === Node.TEXT_NODE)
          .map((n) => n.textContent)
          .join('');
        if (/\d/.test(ownText)) {
          const s = getComputedStyle(el);
          numeric.push({ tag: el.tagName, family: s.fontFamily, variant: s.fontVariantNumeric, ownText: ownText.trim().slice(0, 40) });
        }
      }
      return numeric;
    })()
  JS
end

def expect_numeric_data!
  elements = numeric_data_elements
  # Non-vacuity guard: the Then steps assert over a NON-EMPTY set of numeric
  # data — if the page ever regresses to rendering zero numeric elements the
  # scenarios fail instead of passing vacuously over an empty collection.
  expect(elements).not_to be_empty, 'no numeric data found on the page'
  elements
end

When(/^I view the page with numeric data$/) do
  visit experiment_path(experiment_named('Donation amounts'))
end

Then(/^every numeric datum renders in a mono face$/) do
  expect_numeric_data!.each do |datum|
    expect(datum['family']).to match(/mono|Menlo|Consolas|Monaco/i),
                               "#{datum['tag']} renders numeric text (#{datum['ownText'].inspect}) in a non-mono face: #{datum['family']}"
  end
end

Then(/^every numeric datum uses tabular numeral features$/) do
  expect_numeric_data!.each do |datum|
    expect(datum['variant']).to include('tabular-nums'),
                                "#{datum['tag']} renders numeric text (#{datum['ownText'].inspect}) without tabular numerals: #{datum['variant']}"
  end
end
