# frozen_string_literal: true

# Step definitions for PRD-0004 — the graphical chromosome designer.
# DEV-0001 (issue #77): a user creates a chromosome with mixed allele types
# (float + integer + boolean) through the single-surface designer and sees a
# live preview of the allele set, saved under their organization. Factory
# truth: :organization / :user / :org_membership factories in spec/factories/
# — the Background sign-in step is shared with the PRD-0003 feature
# (experiment_workspace.rb) and reused, never redefined.

# The designer is a server-rendered single-surface form: a chromosome name
# plus allele cards (name + type select + type-specific fields) and an "Add
# allele" round trip that preserves the entered cards. The When drives the
# real UI: fill card, add allele, repeat, then submit the create form.
When(/^I create a chromosome with a float, an integer, and a boolean allele$/) do
  visit new_chromosome_path
  fill_in 'Name', with: 'Mixed genome'

  fill_allele_card(0, type: 'Float', name: 'weight', minimum: '0', maximum: '10')
  click_button 'Add allele'
  fill_allele_card(1, type: 'Integer', name: 'limbs', minimum: '2', maximum: '4')
  click_button 'Add allele'
  fill_allele_card(2, type: 'Boolean', name: 'wings')

  click_button 'Create chromosome'
end

Then(/^I see a live preview of all three alleles$/) do
  expect(page).to have_css('.allele-preview-item', count: 3)
  expect(page).to have_content('weight')
  expect(page).to have_content('limbs')
  expect(page).to have_content('wings')
end

And(/^the chromosome is saved under my organization$/) do
  chromosome = Chromosome.find_by!(name: 'Mixed genome')
  expect(chromosome.organization.name).to eq('Loop Labs')
  expect(chromosome.alleles.map(&:name)).to match_array(%w[weight limbs wings])
  expect(chromosome.alleles.map(&:type)).to match_array(%w[Float Integer Boolean])
end

# Fills one named allele card in the designer. The card index is stable
# across "Add allele" round trips (server re-renders preserve the entered
# cards in order).
def fill_allele_card(index, type:, name:, minimum: nil, maximum: nil)
  within(all('.allele-card')[index]) do
    select type, from: 'Type'
    fill_in 'Allele name', with: name
    fill_in 'Minimum', with: minimum if minimum
    fill_in 'Maximum', with: maximum if maximum
  end
end

# PRD-0004 DEV-0002 (issue #78): a float allele whose minimum exceeds its
# maximum is an inline validation error on the re-rendered designer, and
# neither the allele nor its chromosome is saved (atomic designer create).
Given(/^I am adding a float allele to a chromosome$/) do
  visit new_chromosome_path
  fill_in 'Name', with: 'Bounded genome'
  fill_allele_card(0, type: 'Float', name: 'weight', minimum: '0', maximum: '10')
end

When(/^I set a minimum greater than the maximum$/) do
  within(all('.allele-card')[0]) do
    fill_in 'Minimum', with: '10'
    fill_in 'Maximum', with: '1'
  end
  click_button 'Create chromosome'
end

# Shared by DEV-0002 (bounds) and DEV-0003 (empty choice list): both are
# inline per-card validation errors. The precise message text for each case
# is asserted at the request-spec level; here we assert the inline surface.
Then(/^I see an inline validation error$/) do
  expect(page).to have_css('.allele-error')
end

And(/^the allele is not saved$/) do
  expect(Chromosome.find_by(name: 'Bounded genome')).to be_nil
  expect(Allele.where(name: 'weight')).to be_empty
end

# PRD-0004 DEV-0003 (issue #79): an option allele whose choice list is left
# empty is an inline validation error on the re-rendered designer, and
# nothing is saved (atomic designer create). The choices text input is
# simply never filled, so the card submits choices: "".
Given(/^I am adding an option allele to a chromosome$/) do
  visit new_chromosome_path
  fill_in 'Name', with: 'Option genome'
  fill_allele_card(0, type: 'Option', name: 'flavor')
end

When(/^I leave the choice list empty$/) do
  click_button 'Create chromosome'
end

# Finding #148 (T2) — type-aware allele card fields. The field set is
# server-rendered per card[:type]; the type-change mechanism is the existing
# Add-allele round trip (it re-renders preserving the entered cards, so
# changing the Type select then submitting re-renders the card with its new
# field set, no JS). @javascript (real browser) because the finding was filed
# from a live walk where the request layer rendered every field for every
# type and stayed green.
Given(/^I am designing a chromosome$/) do
  # The Background sign-in submits through Turbo: in a real browser the
  # session cookie lands asynchronously, so the first visit can race ahead of
  # it and bounce to /login (the .allele-card scope comes back empty — the
  # same async-Turbo race class as finding #147). has_css? waits for the
  # designer to render; a bounded revisit settles the cookie race.
  3.times do
    break if page.has_css?('.allele-card', count: 1)

    visit new_chromosome_path
  end
  expect(page).to have_css('.allele-card', count: 1)
end

When(/^I walk the first allele card through every allele type$/) do
  %w[Option Boolean Integer].each do |type|
    within(all('.allele-card')[0]) do
      select type, from: 'Type'
    end
    cards_before = all('.allele-card').count
    click_button 'Add allele'
    # The Add-allele round trip appends one card: the count only grows when
    # the server re-render lands in the browser. (Before finding #147's
    # transport opt-out the Turbo-intercepted response was discarded and this
    # step timed out — the exact live-walk symptom finding #148 was filed
    # from.)
    expect(page).to have_css('.allele-card', count: cards_before + 1)
    # The changed card (0) must already show its new type's field set.
    expect_field_set_for_card(0, type)
  end
end

# The walk leaves card 0 as Integer plus one blank Float card per round trip:
# every card on the page must show exactly its own type's fields, nothing
# more.
Then(/^each allele card shows only its type's fields$/) do
  all('.allele-card').each_with_index do |_card, index|
    type = within(all('.allele-card')[index]) { find('select').value }
    expect_field_set_for_card(index, type)
  end
end

def expect_field_set_for_card(index, type)
  within(all('.allele-card')[index]) do
    expect(page).to have_field('Allele name')
    case type
    when 'Float', 'Integer'
      expect(page).to have_field('Minimum')
      expect(page).to have_field('Maximum')
      expect(page).not_to have_field('Choices')
    when 'Boolean'
      expect(page).not_to have_field('Minimum')
      expect(page).not_to have_field('Maximum')
      expect(page).not_to have_field('Choices')
    when 'Option'
      expect(page).to have_field('Choices')
      expect(page).not_to have_field('Minimum')
      expect(page).not_to have_field('Maximum')
    end
  end
end
