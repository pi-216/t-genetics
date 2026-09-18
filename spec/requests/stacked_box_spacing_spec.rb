# frozen_string_literal: true

require 'rails_helper'

# Issue #205 — stacked box components used to sit flush: CardComponent and
# TableComponent rendered block-level panels with no bottom rhythm, and the
# index views stacked them back-to-back (the /organization/api_tokens "Create a
# token" card touching the token table). The rhythm belongs to the box itself
# (mb-6 = the DESIGN.md lg step, 24px — the step PageHeaderComponent already
# carries) so it reaches through any wrapper; a container that owns its own
# rhythm (a grid/flex row) is the only place a box opts out. These sweeps are
# the convention's guard: every stacked surface carries the rhythm itself, and
# no container in the box's own formatting context re-declares it — two owners
# of the same rhythm is a latent doubling the moment that container stops
# collapsing margins.
module BoxStackRhythm
  BOX_SELECTOR = '.card, .table-wrap, .empty-state'

  def box_panels(body)
    Nokogiri::HTML(body).css(BOX_SELECTOR)
  end

  def expect_stacked_box_rhythm(body, path)
    boxes = box_panels(body)
    expect(boxes).not_to be_empty, "#{path} rendered no box panels"

    boxes.each do |box|
      container = box.parent['class'].to_s
      if box['class'].to_s.include?('mb-6')
        message = "#{path}: box keeps its rhythm and its container also spaces: #{container}"
        expect(container).not_to match(/\b(?:space-y-|gap-)/), message
      else
        message = "#{path}: box #{box['class']} lost its rhythm and its container owns none"
        expect(container).to match(/\b(?:space-y-|gap-)/), message
      end
    end
  end

  # The token page is owner-only (flat roles: a member has no management
  # surface), so this example signs in as an owner, not the member default.
  def sign_in_as_owner(organization)
    owner = FactoryBot.create(:user)
    FactoryBot.create(:org_membership, user: owner, organization:,
                                       role: Identity::OrgMembership::OWNER_ROLE)
    post login_path, params: { identity_user: { email: owner.email, password: owner.password } }
  end
end

RSpec.describe 'Stacked box rhythm (issue #205)' do
  include BoxStackRhythm

  let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }
  let(:chromosome) { FactoryBot.create(:chromosome, name: 'Mixed genome', organization:) }
  let(:allele) { FactoryBot.create(:allele, chromosome:, name: 'weight') }
  let(:organism) { FactoryBot.create(:organism, generation: FactoryBot.create(:generation, chromosome:)) }
  let(:experiment) do
    FactoryBot.create(:experiment, name: 'Donation amounts', chromosome:, external_entity: chromosome)
  end
  # Every live surface that renders a box panel — the token page, the settings
  # page, the chromosome pages, the experiment pages, the invite page.
  let(:stacked_box_paths) do
    [settings_path, api_tokens_index_path, chromosome_path(chromosome),
     new_chromosome_allele_path(chromosome), edit_chromosome_allele_path(chromosome, allele),
     chromosome_generation_organism_path(chromosome, organism.generation, organism),
     experiments_path, experiment_path(experiment), history_experiment_path(experiment),
     organization_invite_code_path]
  end

  before { sign_in_as_owner(organization) }

  # The founder's case: the token page stacks the create card on top of the
  # token table with nothing between them.
  it 'separates the create card from the token table on the token page' do
    get api_tokens_index_path

    expect(response).to have_http_status(:ok)
    boxes = box_panels(response.body)
    expect(boxes.size).to be >= 2, 'expected the create card and the token table'
    expect_stacked_box_rhythm(response.body, api_tokens_index_path)
  end

  # Every surface that stacks boxes — the token page, the settings page, the
  # chromosome pages, the experiment pages — carries the convention.
  it 'gives every stacked box surface the rhythm and no container a second one' do
    stacked_box_paths.each do |path|
      get path

      expect(response).to have_http_status(:ok), "expected #{path} to render"
      expect_stacked_box_rhythm(response.body, path)
    end
  end

  # The sweep above only sees a box's own parent, so the seam a NON-box block
  # opens needs its own guard: the experiment page's two-column grid spaces its
  # own cards (gap-6, spacing: false) and must therefore own the rhythm below
  # itself too, or the fitness-trend panel sits flush against the grid (the
  # mt-4 wrapper went with the container that used to space it). The real gap
  # is measured in the browser by the @DEV-0205 experiment scenario.
  it 'has the experiment grid own the rhythm below itself' do
    get experiment_path(experiment)

    expect(response).to have_http_status(:ok)
    grid = Nokogiri::HTML(response.body).css('.fitness-trend-panel').first.previous_element
    expect(grid['class'].to_s).to include('mb-6'),
                                  "the grid above the trend panel owns no rhythm: #{grid['class']}"
  end
end
