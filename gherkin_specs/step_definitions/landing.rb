# frozen_string_literal: true

# Step definitions for PRD-0001 — public landing page (DEV-0001: the page
# renders with the core message; DEV-0002: the call to action leads to
# sign-up). Public route, no auth, no DB — plain Capybara/rack_test
# assertions against the root route.

Given(/^I am on the landing page$/) do
  visit root_path
  expect(page).to have_current_path(root_path)
end

When(/^I read the page content$/) do
  expect(page.status_code).to eq(200)
end

Then(/^I see the product name$/) do
  expect(page).to have_content('TGenetics')
end

Then(/^I see an explanation of the evolution loop$/) do
  expect(page).to have_content('report one number')
  expect(page).to have_content('offspring')
end

Then(/^I see a "([^"]+)" call to action$/) do |label|
  expect(page).to have_link(label, href: register_path)
end

# DEV-0002 — the "Start free" CTA on the landing page links into the
# PRD-0002 sign-up flow. The sign-up page is identified by its heading
# (same marker the registration steps assert).
When(/^I click the "([^"]+)" call to action$/) do |label|
  click_link label
end

Then(/^I land on the sign-up page$/) do
  expect(page).to have_current_path(register_path)
  expect(page).to have_content('Create your account')
end

# DEV-0003 — the landing page carries a trust block that states the core
# product contract: the customer keeps their fitness function. We never
# run or evaluate it for them (HANDOFF red line); the page just says so.
When(/^I read the trust section$/) do
  expect(page).to have_css('#trust')
end

Then(/^I see a statement that my fitness function stays mine$/) do
  expect(page).to have_content('Your fitness function stays yours')
end

# DEV-0004 — the pricing section shows the posture (a Free tier for the
# basic loop; a paid tier comes later) WITHOUT promising or describing
# paid-tier specifics. Paid-tier features (exploitation/greed control,
# time-to-result optimization, generation insights) are a red line until
# the first paying customer exists — the page must not name or offer them.
When(/^I read the pricing section$/) do
  expect(page).to have_css('#pricing')
end

Then(/^I see a Free tier for the basic loop$/) do
  expect(page).to have_content('Free tier')
  expect(page).to have_content('basic loop')
end

Then(/^I see no paid feature specifics implemented$/) do
  expect(page).to have_no_content('exploitation')
  expect(page).to have_no_content('greed')
  expect(page).to have_no_content('time-to-result')
  expect(page).to have_no_content('insights')
end

# DEV-0006 — the footer carries placeholder links for future privacy and
# terms pages (the pages themselves are PRD-0001 non-goals; the links are
# the scope). The footer lives in the shared application layout, so the
# guard covers every page, not just the landing page.
When(/^I inspect the page footer$/) do
  expect(page).to have_css('footer')
end

Then(/^I see a privacy link$/) do
  within('footer') do
    expect(page).to have_link('Privacy', href: '#')
  end
end

Then(/^I see a terms link$/) do
  within('footer') do
    expect(page).to have_link('Terms', href: '#')
  end
end

# Issue #132 (founder direction 2026-09-06) — the landing page sweep:
#  - DEV-0142: a plain-language GA primer — the evolutionary loop
#    (variation → test → selection → repeat) searching a design space against
#    a fitness function the customer owns.
#  - DEV-0143: concrete use-case cards (≥3), including the payment-form tip
#    suggestion case.
#  - DEV-0144: a "create a genome" walkthrough with REAL screenshots of the
#    live chromosome designer and experiment workspace, served as local
#    assets (same-host src) — the walkthrough and its images are the section.
#
# Section ids are the stable selectors (the sabotage discipline: remove the
# section or swap an image to an external host and the scenario dies).

When(/^I read the GA primer section$/) do
  expect(page).to have_css('#what-is-a-ga')
end

Then(/^I see a plain-language explanation of a genetic algorithm$/) do
  expect(page).to have_content('genetic algorithm')
  expect(page).to have_content('evolutionary loop')
end

Then(/^I see that the loop searches a design space the customer owns$/) do
  expect(page).to have_content('design space')
  expect(page).to have_content('fitness function')
end

When(/^I read the use case cards$/) do
  expect(page).to have_css('#use-cases')
end

Then(/^I see at least three use cases$/) do
  use_case_cards = page.all('.use-case-card')
  expect(use_case_cards.length).to be >= 3
end

Then(/^I see the payment form tip suggestion use case$/) do
  expect(page).to have_content(/payment form/i)
  expect(page).to have_content(/tip/i)
end

When(/^I read the genome walkthrough section$/) do
  expect(page).to have_css('#create-a-genome')
end

Then(/^I see an explanation of typed alleles$/) do
  expect(page).to have_content('typed alleles')
  expect(page).to have_content('Float')
  expect(page).to have_content('Integer')
  expect(page).to have_content('Boolean')
  expect(page).to have_content('Option')
end

Then(/^I see a real screenshot of the chromosome designer served from the app$/) do
  # Mobile-width capture is the img fallback; the desktop-width capture is the
  # picture source for ≥640px viewports. Both must be real, same-host assets.
  designer_img = page.all('img[src*="/assets/"]').find { |img| img[:alt].to_s.match?(/chromosome designer/i) }
  expect(designer_img).to be_present
  expect(designer_img[:src]).to start_with('/assets/')
  designer_src = page.all('picture source[srcset*="designer-desktop"]').first
  expect(designer_src).to be_present
  expect(designer_src[:srcset]).to start_with('/assets/')
end

Then(/^I see a real screenshot of the experiment workspace served from the app$/) do
  experiment_img = page.all('img[src*="/assets/"]').find { |img| img[:alt].to_s.match?(/experiment/i) }
  expect(experiment_img).to be_present
  expect(experiment_img[:src]).to start_with('/assets/')
  experiment_src = page.all('picture source[srcset*="experiment-desktop"]').first
  expect(experiment_src).to be_present
  expect(experiment_src[:srcset]).to start_with('/assets/')
end
