# frozen_string_literal: true

# Step definitions for PRD-0003 — the experiment workspace (the loop, in the
# UI). DEV-0001 (issue #68): a member creates a named experiment on an org
# chromosome with a population size and sees it (not yet ripe) under their
# organization. Factory truth: :organization / :chromosome / :user /
# :org_membership factories in spec/factories/ — never invented fields.
# The "organization X owns chromosome Y" background step is shared with the
# PRD-0005 feature (gherkin_specs/step_definitions/api_tokens.rb) — reuse, do
# not redefine.

Given(/^I am signed in as an owner of(?: organization)? "([^"]+)"$/) do |org_name|
  organization = Identity::Organization.find_or_create_by!(name: org_name)
  # Marks the WEB feature context for the shared Given in api_tokens.rb
  # ("a suggestion has been requested for the experiment") — a browser session
  # exists here, so the web loop flow runs, not the token flow.
  @signed_in_org = organization
  email = "owner-#{organization.name.parameterize}@example.com"
  password = 'S3cretPass!'
  user = Identity::User.find_or_create_by!(email:) do |u|
    u.password = password
  end
  Identity::OrgMembership.find_or_create_by!(user:, organization:) do |m|
    m.role = Identity::OrgMembership::OWNER_ROLE
  end

  visit login_path
  fill_in 'Email', with: email
  fill_in 'Password', with: password
  click_button 'Sign in'
end

When(/^I create the "([^"]+)" experiment on "([^"]+)" with population (\d+)$/) do |name, chromosome_name, population|
  visit new_experiment_path
  fill_in 'Name', with: name
  select chromosome_name, from: 'experiment_chromosome_id'
  fill_in 'Population size', with: population
  click_button 'Create experiment'
end

Then(/^I see the experiment under my organization$/) do
  # The create flow lands on the org-scoped experiment detail page — the new
  # experiment is visible under our organization. The org-scoped INDEX listing
  # is covered separately by spec/requests/experiments_spec.rb.
  expect(page).to have_content('Donation amounts')
  expect(page).to have_content('Alpha-chrom')
end

And(/^evolution is not yet ripe$/) do
  expect(page).to have_content(/not yet ripe/i)
end

# DEV-0003 (issue #70) — a member requests a suggestion from the experiment
# show page. The scenario Background owns only the chromosome; the named
# experiment is an implicit prerequisite, created through the same Setup
# command the UI create flow runs, then the suggestion is requested through
# the real UI (POST to the show page's request button). Factory truth:
# :experiment/:chromosome factories in spec/factories/.
When(/^I request a suggestion for the experiment$/) do
  experiment = experiment_named('Donation amounts')

  visit experiment_path(experiment)
  click_button 'Request suggestion'
end

Then(/^I receive an organism with values from the current generation$/) do
  expect(page).to have_css('.suggested-organism')
  chromosome = Chromosome.find_by!(name: 'Alpha-chrom')
  chromosome.alleles.map(&:name).each do |allele_name|
    expect(page).to have_content(allele_name)
  end
end

And(/^a performance log entry records the suggestion$/) do
  experiment = Experiment.find_by!(name: 'Donation amounts')
  logs = PerformanceLog.where(experiment_id: experiment.id)
  expect(logs.size).to eq(1)
  expect(logs.first.organism.generation).to eq(experiment.current_generation)
  expect(logs.first.suggested_at).to be_present
end

# DEV-0004 (issue #71) — a member reports the ONE fitness number for the
# latest suggestion (the show page's report form runs the engine's
# Experiments::RecordOutcome). The Given for this scenario ("a suggestion has
# been requested for the experiment") is shared with the token-API feature and
# lives in api_tokens.rb — it branches on feature context and delegates here
# via `step` for the web flow.

When(/^I report fitness ([\d.]+) for that suggestion$/) do |fitness|
  fill_in 'Fitness', with: fitness
  click_button 'Report fitness'
end

Then(/^the fitness ([\d.]+) is recorded against that suggestion$/) do |fitness|
  experiment = Experiment.find_by!(name: 'Donation amounts')
  log = PerformanceLog.where(experiment_id: experiment.id).order(:id).last
  expect(log.fitness_input_value).to eq(fitness.to_f)
  expect(log.outcome_recorded_at).to be_present
  expect(page).to have_css('.recorded-fitness')
  expect(page).to have_content("Recorded fitness: #{fitness}")
end

# DEV-0005 (issue #72) — a ripe experiment evolves on the next loop action.
# The Given drives the real loop commands (suggest → report) against the
# experiment created by `experiment_named` until the product's own
# `ripe_for_evolution?` turns true — nothing hand-built. The experiment is
# transitioned to `running` first (ripe_for_evolution? only considers running
# experiments — the AASM event the engine's own commands use). The When reuses
# the shared request-suggestion step: the next loop action must trigger
# Experiments::EvaluateAndEvolve before suggesting, per PRD-0003.
Given(/^the experiment has enough reported outcomes to be ripe$/) do
  experiment = experiment_named('Donation amounts')
  experiment.start! # pending → running; ripeness requires a running experiment

  until experiment.reload.ripe_for_evolution?
    suggestion = Experiments::RequestSuggestion.call(experiment:)
    raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

    outcome = Experiments::RecordOutcome.call(performance_log: suggestion.performance_log,
                                              fitness_input_value: 0.81)
    raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
  end

  expect(experiment.ripe_for_evolution?).to be true
end

When(/^I request the next suggestion$/) do
  step 'I request a suggestion for the experiment'
end

Then(/^a new generation is created$/) do
  experiment = Experiment.find_by!(name: 'Donation amounts')
  # Setup births generation 0; a successful evolution creates iteration 1.
  expect(experiment.reload.current_generation.iteration).to eq(1)
  expect(Generation.where(chromosome: experiment.chromosome).count).to eq(2)
end

And(/^it replaces the current generation$/) do
  experiment = Experiment.find_by!(name: 'Donation amounts')
  log = PerformanceLog.where(experiment_id: experiment.id).order(:id).last
  # The suggestion served after evolution comes from the NEW generation, and
  # the show page reflects it (the suggested-organism section renders the
  # generation iteration).
  expect(log.organism.generation.iteration).to eq(1)
  expect(page).to have_content('from generation 1')
end

# DEV-0006 (issue #73) — evolution does not double-fire. The double-fire
# hazard: two loop actions (a double-click, web + machine API racing, or a
# client retry) can BOTH pass the ripe check before either commits, and each
# then runs EvaluateAndEvolve against the same pre-evolution state — creating
# TWO sibling generations from one parent. The scenario drives the real loop
# commands twice against the same ripe (pre-evolution) experiment view, and
# asserts exactly one offspring generation exists afterwards (regression:
# the engine must serialize evolution on the experiment row and adopt the
# concurrent winner instead of breeding a duplicate).
Given(/^the experiment is ripe$/) do
  experiment = experiment_named('Donation amounts')
  experiment.start! # pending → running; ripeness requires a running experiment
  until experiment.reload.ripe_for_evolution?
    suggestion = Experiments::RequestSuggestion.call(experiment:)
    raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

    outcome = Experiments::RecordOutcome.call(performance_log: suggestion.performance_log,
                                              fitness_input_value: 0.81)
    raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
  end

  expect(experiment.ripe_for_evolution?).to be true
end

When(/^the next loop action runs twice$/) do
  experiment = experiment_named('Donation amounts')
  # Both loop actions observe the SAME pre-evolution ripe state (the race
  # window): the second view is loaded before the first action's evolution
  # commits, exactly like two concurrent requests would.
  racing_view = Experiment.find(experiment.id)
  racing_view.current_generation # cache the pre-evolution generation on this view

  2.times do |i|
    view = i.zero? ? experiment : racing_view
    suggestion = Experiments::RequestSuggestion.call(experiment: view)
    raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?
  end
end

Then(/^exactly one new generation is created$/) do
  experiment = Experiment.find_by!(name: 'Donation amounts')
  # Setup births generation 0; one successful evolution creates iteration 1.
  # A double-fire would leave TWO offspring generations (both iteration 1).
  expect(Generation.where(chromosome: experiment.chromosome).count).to eq(2)
  expect(Generation.where(chromosome: experiment.chromosome, iteration: 1).count).to eq(1)
end

# DEV-0002 (issue #69) — another organization cannot see my experiment. The
# scenario re-signs-in as a different org after the Background, so the sign-in
# step above accepts both phrasings ("owner of X" and "owner of organization
# X" — the latter also used by the PRD-0004 designer feature). Visiting the
# named experiment's direct URL must answer 404 for the foreign org — the
# controller's org-scoped lookup never discloses it (PRD-0003 red line).
When(/^I visit the experiment "([^"]+)"$/) do |experiment_name|
  visit experiment_path(experiment_named(experiment_name))
end

# DEV-0007 (issue #74) — a member can browse the experiment's generation
# history. The Given drives the real loop (suggest → report → auto-evolve)
# twice, exactly like the DEV-0005 Given but repeated, so generations 0, 1, 2
# exist; the When opens the org-scoped history page; the Then asserts every
# generation is listed with its organisms and the recorded fitness.
Given(/^the experiment has evolved more than once$/) do
  experiment = experiment_named('Donation amounts')
  experiment.start!

  2.times do
    until experiment.reload.ripe_for_evolution?
      suggestion = Experiments::RequestSuggestion.call(experiment:)
      raise "RequestSuggestion failed: #{suggestion.errors.inspect}" unless suggestion.success?

      outcome = Experiments::RecordOutcome.call(performance_log: suggestion.performance_log,
                                                fitness_input_value: 0.81)
      raise "RecordOutcome failed: #{outcome.errors.inspect}" unless outcome.success?
    end

    next_suggestion = Experiments::RequestSuggestion.call(experiment:)
    raise "RequestSuggestion failed: #{next_suggestion.errors.inspect}" unless next_suggestion.success?
  end

  expect(experiment.reload.current_generation.iteration).to eq(2)
end

When(/^I open the generation history$/) do
  visit history_experiment_path(experiment_named('Donation amounts'))
end

Then(/^I see each generation with its organisms and recorded fitness$/) do
  experiment = Experiment.find_by!(name: 'Donation amounts')
  generations = Generation.where(chromosome: experiment.chromosome).order(:iteration)
  expect(generations.size).to be >= 3

  generations.each do |generation|
    expect(page).to have_content("Generation #{generation.iteration}")
    expect(page).to have_content("#{generation.organisms.count} organisms")
    generation.organisms.each do |organism|
      expect(page).to have_content("Organism ##{organism.id}")
    end
  end

  expect(page).to have_content('Recorded fitness:')
  expect(page).to have_content('0.81')
end

# The named experiment is an implicit prerequisite for several scenarios —
# created through the same Experiments::Setup command the UI create flow runs
# (never a factory where the real command exists). Shared by the suggestion
# and the visit steps above.
def experiment_named(experiment_name)
  chromosome = Chromosome.find_by!(name: 'Alpha-chrom')
  experiment = Experiment.find_by(name: experiment_name, chromosome:)
  return experiment if experiment

  result = Experiments::Setup.call(chromosome:,
                                   external_entity: chromosome,
                                   name: experiment_name,
                                   experiment_configuration: { population_size: 20 })
  raise "Setup failed: #{result.errors.inspect}" unless result.success?

  result.experiment
end
