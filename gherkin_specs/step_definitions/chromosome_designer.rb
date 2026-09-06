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

Then(/^I see an inline validation error$/) do
  expect(page).to have_css('.allele-error', text: /less than or equal/i)
end

And(/^the allele is not saved$/) do
  expect(Chromosome.find_by(name: 'Bounded genome')).to be_nil
  expect(Allele.where(name: 'weight')).to be_empty
end
