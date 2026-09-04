# frozen_string_literal: true

# Step definitions for PRD-0004 DEV-0006 (issue #82) — the fitness trend.
# The Given drives the real loop (suggest → report → auto-evolve) twice, so
# generations 0, 1, and 2 exist and generations 0 and 1 carry the recorded
# (customer-reported) fitness averages — the same state the PRD-0003 history
# Given produces. The trend is rendered on the experiment show page as a
# self-hosted inline SVG (no charting gem, no external CDN — dependency +
# network red line, drift flag A2 in the PRD-0004 feature header).

Given(/^the experiment has generations with recorded fitness$/) do
  # The PRD-0004 feature Background signs in only; ensure the chromosome the
  # PRD-0003 helper looks up exists under the signed-in organization.
  organization = Identity::Organization.find_by!(name: 'Loop Labs')
  Chromosome.find_or_create_by!(name: 'Alpha-chrom', organization: organization)

  step 'the experiment has evolved more than once'
end

When(/^I view the fitness trend$/) do
  visit experiment_path(experiment_named('Donation amounts'))
end

Then(/^I see a per-generation trend line$/) do
  expect(page).to have_css('.fitness-trend')
  # One point per generation with recorded fitness — generations 0 and 1
  # (generation 2's organisms have not been evaluated yet).
  expect(page).to have_css('.fitness-trend-point', count: 2)
  expect(page).to have_css('.fitness-trend-point[data-generation="0"]')
  expect(page).to have_css('.fitness-trend-point[data-generation="1"]')
  # The connecting trend line is a self-hosted inline SVG polyline.
  expect(page).to have_css('.fitness-trend svg polyline.fitness-trend-line')
end

And(/^no external charting is loaded$/) do
  external_script_srcs = page.all('script[src]').filter_map { |script| script[:src] }
                             .grep(%r{\Ahttps?://})
  expect(external_script_srcs).to be_empty
end

# Step definitions for PRD-0004 DEV-0007 (issue #83) — the explicit empty
# state. The Given creates the named experiment through the real Setup
# command but requests no suggestion and reports no outcome, so the
# experiment's generations exist yet no organism carries a recorded fitness —
# exactly the state the empty-state behavior targets.

Given(/^the experiment has no recorded fitness$/) do
  organization = Identity::Organization.find_by!(name: 'Loop Labs')
  Chromosome.find_or_create_by!(name: 'Alpha-chrom', organization: organization)

  experiment_named('Donation amounts')
end

Then(/^I see an explicit empty state$/) do
  expect(page).to have_css('.fitness-trend-empty')
  expect(page).to have_content('No fitness recorded yet')
  expect(page).not_to have_css('.fitness-trend-point')
end
