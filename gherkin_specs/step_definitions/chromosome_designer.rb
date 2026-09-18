# frozen_string_literal: true

# Step definitions for PRD-0004 (issue #184, PO ruling 2026-09-15) — the
# standard-CRUD chromosome/allele flow replaces the single-surface designer:
# create the chromosome by name only, land on its show page (empty allele
# state), then add/edit/destroy alleles through their own nested forms (each
# mutation redirecting back to the show page). Factory truth:
# :organization / :user / :org_membership factories in spec/factories/ —
# the Background sign-in step is shared with the PRD-0003 feature
# (experiment_workspace.rb) and reused, never redefined.

# --- chromosome create (name only) ---

Given(/^a chromosome named "([^"]+)"$/) do |name|
  org = Identity::Organization.find_by!(name: 'Loop Labs')
  FactoryBot.create(:chromosome, name:, organization: org)
end

When(/^I create a chromosome with the name "([^"]+)"$/) do |name|
  visit new_chromosome_path
  fill_in 'chromosome_name', with: name
  click_button 'Create chromosome'
  # Classic (non-Turbo) POST -> redirect to the show page: wait for the
  # navigation to settle before any element assertion, or Selenium resolves
  # old-document nodes mid-teardown ("Node with given id does not belong to
  # the document").
  expect(page).to have_current_path(%r{/chromosomes/\d+})
end

Then(/^I see the empty allele state on the chromosome$/) do
  expect(page).to have_css('.empty-state')
  expect(page).to have_content('No alleles yet')
  # The empty state must carry an action to escape it.
  expect(page).to have_link('Add allele', href: %r{/chromosomes/\d+/alleles/new})
end

Then(/^the chromosome is saved under my organization$/) do
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  expect(chromosome.organization.name).to eq('Loop Labs')
end

# --- allele creation (nested form) ---

When(/^I add a float allele "([^"]+)" bounded by (\d+) and (\d+)$/) do |name, minimum, maximum|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  visit new_chromosome_allele_path(chromosome)
  select 'Float', from: 'allele_type'
  fill_in 'allele_name', with: name
  fill_in 'allele_minimum', with: minimum
  fill_in 'allele_maximum', with: maximum
  click_button 'Create allele'
  # The redirect target is the chromosome SHOW page; the allele new-form URL
  # also matches an unanchored /chromosomes/\d+ regex, so assert the exact
  # path and let the navigation settle before the next step.
  expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
end

When(/^I add an integer allele "([^"]+)" bounded by (\d+) and (\d+)$/) do |name, minimum, maximum|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  visit new_chromosome_allele_path(chromosome)
  select 'Integer', from: 'allele_type'
  fill_in 'allele_name', with: name
  fill_in 'allele_minimum', with: minimum
  fill_in 'allele_maximum', with: maximum
  click_button 'Create allele'
  expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
end

When(/^I add a boolean allele "([^"]+)"$/) do |name|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  visit new_chromosome_allele_path(chromosome)
  select 'Boolean', from: 'allele_type'
  fill_in 'allele_name', with: name
  click_button 'Create allele'
  expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
end

# Issue #210 — the browser can only send the choices field as one
# comma-separated string; the array form belongs to the machine contract.
When(/^I add an option allele "([^"]+)" with the choices "([^"]+)"$/) do |name, choices|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  visit new_chromosome_allele_path(chromosome)
  select 'Option', from: 'allele_type'
  fill_in 'allele_name', with: name
  fill_in 'allele_choices', with: choices
  click_button 'Create allele'
  expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
end

# One compound When drives all three allele adds (gherkin_lint
# AvoidScripting: one action per scenario — the loop lives in this step).
# rubocop:disable Metrics/ParameterLists
# -- seven capture groups map the BDD sentence's allele fields 1:1; the loop
# lives in this one compound When step (gherkin_lint AvoidScripting).
When(/^I add a float allele "([^"]+)" (\d+)\.\.(\d+), integer "([^"]+)" (\d+)\.\.(\d+), boolean "([^"]+)"$/) do |fname, fmin, fmax, iname, imin, imax, bname|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  [['Float', fname, fmin, fmax], ['Integer', iname, imin, imax], ['Boolean', bname, nil, nil]].each do |type, name, minimum, maximum|
    visit new_chromosome_allele_path(chromosome)
    select type, from: 'allele_type'
    fill_in 'allele_name', with: name
    if minimum && maximum
      fill_in 'allele_minimum', with: minimum
      fill_in 'allele_maximum', with: maximum
    end
    click_button 'Create allele'
    expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
  end
end
# rubocop:enable Metrics/ParameterLists

Then(/^I am back on the chromosome show page and see the allele "([^"]+)"$/) do |name|
  expect(page).to have_current_path(%r{\A/chromosomes/\d+\z})
  expect(page).to have_css('.allele-name', text: name)
end

# Issue #209 — the mutation's success notice must be visible on the page the
# redirect lands on (the layout renders the flash partial).
Then(/^I see the success notice "([^"]+)"$/) do |text|
  notice = find('#notice')
  expect(notice['role']).to eq('alert')
  expect(notice).to have_text(text)
end

Then(/^the allele "([^"]+)" shows the choices "([^"]+)"$/) do |name, choices|
  row = find('.allele-preview-item', text: name)
  expect(row.find('.allele-name')).to have_text(name)
  expect(row).to have_css('.allele-choices', text: "[#{choices}]")
end

Then(/^the chromosome has exactly (\d+) allele$/) do |count|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  expect(chromosome.alleles.count).to eq(count.to_i)
end

Then(/^the chromosome is saved with exactly those (\d+) alleles$/) do |count|
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  expect(chromosome.alleles.count).to eq(count.to_i)
  expect(chromosome.alleles.map(&:name)).to match_array(%w[weight limbs wings])
end

# --- inline validation on the allele form ---

Given(/^I am adding a float allele to a chromosome$/) do
  chromosome = FactoryBot.create(:chromosome, name: 'Bounded genome', organization: Identity::Organization.find_by!(name: 'Loop Labs'))
  visit new_chromosome_allele_path(chromosome)
  select 'Float', from: 'allele_type'
  fill_in 'allele_name', with: 'weight'
  fill_in 'allele_minimum', with: '0'
  fill_in 'allele_maximum', with: '10'
end

Given(/^I am adding an option allele to a chromosome$/) do
  chromosome = FactoryBot.create(:chromosome, name: 'Option genome', organization: Identity::Organization.find_by!(name: 'Loop Labs'))
  visit new_chromosome_allele_path(chromosome)
  select 'Option', from: 'allele_type'
  fill_in 'allele_name', with: 'flavor'
end

Given(/^I am adding an allele to a chromosome$/) do
  chromosome = FactoryBot.create(:chromosome, name: 'Typed genome', organization: Identity::Organization.find_by!(name: 'Loop Labs'))
  visit new_chromosome_allele_path(chromosome)
  fill_in 'allele_name', with: 'sample'
end

When(/^I set a minimum greater than the maximum$/) do
  fill_in 'allele_minimum', with: '10'
  fill_in 'allele_maximum', with: '1'
  click_button 'Create allele'
end

When(/^I leave the choice list empty$/) do
  click_button 'Create allele'
end

Then(/^I see an inline validation error$/) do
  expect(page).to have_css('.field-error, .command-errors')
end

And(/^the allele is not saved$/) do
  expect(Allele.where(name: 'weight')).to be_empty
  expect(Allele.where(name: 'flavor')).to be_empty
end

# --- duplicate allele names (model-level scoped uniqueness) ---

Given(/^a chromosome with an allele named "([^"]+)"$/) do |name|
  chromosome = FactoryBot.create(:chromosome, name: 'Dup genome', organization: Identity::Organization.find_by!(name: 'Loop Labs'))
  chromosome.alleles << Allele.new_with_float(name:, minimum: 0, maximum: 10)
end

When(/^I add another allele named "([^"]+)"$/) do |name|
  chromosome = Chromosome.find_by!(name: 'Dup genome')
  visit new_chromosome_allele_path(chromosome)
  select 'Float', from: 'allele_type'
  fill_in 'allele_name', with: name
  fill_in 'allele_minimum', with: 0
  fill_in 'allele_maximum', with: 10
  click_button 'Create allele'
end

And(/^the duplicate allele is not saved$/) do
  chromosome = Chromosome.find_by!(name: 'Dup genome')
  expect(chromosome.alleles.count).to eq(1)
end

# --- type-aware form fields (Stimulus toggle in a real browser) ---

When(/^I walk the allele form through every allele type$/) do
  %w[Integer Boolean Option Float].each do |type|
    select type, from: 'allele_type'
    # Client-side selection sets the select's value, not a `selected`
    # attribute in the DOM — read the value, never option[selected].
    expect(find('select#allele_type').value).to eq(type)
    expect_field_set_for_type(type)
  end
end

Then(/^each allele form shows only its type's fields$/) do
  type = find('select#allele_type').value
  expect_field_set_for_type(type)
end

# The visible field set per type (the Stimulus toggle hides the others).
def expect_field_set_for_type(type)
  expect(page).to have_field('allele_name')
  case type
  when 'Float', 'Integer'
    expect(page).to have_field('allele_minimum', visible: :all)
    expect(page).to have_field('allele_maximum', visible: :all)
    expect(page).to have_field('allele_choices', visible: :hidden)
  when 'Boolean'
    expect(page).to have_field('allele_minimum', visible: :hidden)
    expect(page).to have_field('allele_maximum', visible: :hidden)
    expect(page).to have_field('allele_choices', visible: :hidden)
  when 'Option'
    expect(page).to have_field('allele_choices', visible: :all)
    expect(page).to have_field('allele_minimum', visible: :hidden)
    expect(page).to have_field('allele_maximum', visible: :hidden)
  end
end

# --- page-header back link alignment (issue #203) ---

When(/^I open the new allele form for the chromosome$/) do
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  visit new_chromosome_allele_path(chromosome)
  expect(page).to have_current_path(%r{/chromosomes/\d+/alleles/new\z})
end

Then(/^the back link and the heading share the same left edge$/) do
  lefts = {
    back: text_left_edge_of('.page-header a'),
    kicker: text_left_edge_of('.page-header .kicker'),
    title: text_left_edge_of('.page-header h1')
  }
  expect(lefts.values.uniq.size).to eq(1), "back link text is not flush-left with the heading: #{lefts.inspect}"
end

# The TEXT's left edge, not the element's border box: an inline-flex link
# keeps its border box flush with the heading while its horizontal padding
# pushes the glyphs right — exactly the indentation the issue reports, and
# invisible to getBoundingClientRect() on the element itself. A Range over
# the element's contents measures where the text actually starts.
def text_left_edge_of(selector)
  find(selector).evaluate_script(<<~JS).round(1)
    (() => {
      const range = document.createRange();
      range.selectNodeContents(this);
      return range.getBoundingClientRect().left;
    })()
  JS
end

# --- stacked field rhythm (issue #204) ---

# Every VISIBLE field on the form, with the gap inside the pair (label bottom
# → its control top) and the gap to the next field's label. Hidden type
# groups are skipped: display:none boxes have no geometry, and the Stimulus
# toggle decides which single group is live for the selected type.
Then(/^each field is separated from the next by at least its label-to-input gap$/) do
  gaps = page.evaluate_script(<<~JS)
    (() => {
      const fields = Array.from(document.querySelectorAll('form section.field'))
        .filter((field) => field.offsetParent !== null && field.querySelector('label'));
      const control = (field) => field.querySelector('input, select, textarea');
      return fields.map((field, index) => {
        const next = fields[index + 1];
        return {
          within: Math.round(control(field).getBoundingClientRect().top -
                             field.querySelector('label').getBoundingClientRect().bottom),
          between: next
            ? Math.round(next.querySelector('label').getBoundingClientRect().top -
                         control(field).getBoundingClientRect().bottom)
            : null
        };
      });
    })()
  JS

  # Non-vacuity: the form renders its type-aware fields, and the comparison
  # below is only meaningful while the within-pair gap is a real gap.
  expect(gaps.size).to be >= 3, "expected the form's stacked fields, got #{gaps.inspect}"
  expect(gaps.pluck('within').min).to be_positive, "the label→input gap collapsed: #{gaps.inspect}"

  gaps.each do |gap|
    next if gap['between'].nil?

    message = "a field sits closer to its neighbour (#{gap['between']}px) than its label " \
              "sits to its own input (#{gap['within']}px): #{gaps.inspect}"
    expect(gap['between']).to be >= gap['within'], message
  end
end
