# frozen_string_literal: true

require 'rails_helper'

# Issue #204 — stacked form fields used to sit flush against each other: the
# inter-field rhythm lived on whichever container happened to stack the fields
# (space-y-4), so the allele form's type-aware wrappers left label 2 clinging
# to input 1. The rhythm belongs to FormFieldComponent (mb-4 = the DESIGN.md
# md step, 16px: "8px base grid; spacing xs 4 / sm 8 / md 16") and travels
# through any wrapper. These sweeps are the convention's guard: every stacked
# surface carries the rhythm itself, and no container in the field's own
# formatting context re-declares it — two owners of the same rhythm is a
# latent doubling the moment that container stops collapsing margins.
module FieldStackRhythm
  # The guard is scoped to the field's DIRECT parent on purpose: that is the
  # box whose formatting context decides whether a re-declared rhythm adds to
  # the field's own margin (a flex/grid container: margins never collapse) or
  # collapses with it harmlessly (a block stack). A container further up the
  # tree is therefore not a spacing hazard — verified in-browser, where
  # re-declaring space-y-4 on the allele form's outer div leaves the measured
  # gap at the md step.
  def expect_stacked_field_rhythm(body, path)
    fields = Nokogiri::HTML(body).css('form section.field')
    expect(fields).not_to be_empty, "#{path} rendered no form fields"

    fields.each do |field|
      container = field.parent['class'].to_s
      expect(field['class']).to include('mb-4'), "#{path}: field lost its rhythm"
      expect(container).not_to match(/\bspace-y-/), "#{path}: container also spaces: #{container}"
    end
  end

  def form_field_class(body)
    Nokogiri::HTML(body).at_css('form section.field')['class']
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

RSpec.describe 'Form field stack rhythm (issue #204)' do
  include FieldStackRhythm

  describe 'the workspace surfaces' do
    let(:organization) { FactoryBot.create(:organization, name: 'Loop Labs') }

    before { sign_in_as(organization:) }

    it 'gives every stacked field its own rhythm and no container a second one' do
      chromosome = FactoryBot.create(:chromosome, name: 'Mixed genome', organization:)
      FactoryBot.create(:experiment, name: 'Donation amounts', chromosome:, external_entity: chromosome)

      paths = [new_chromosome_path, edit_chromosome_path(chromosome),
               new_chromosome_allele_path(chromosome), new_experiment_path]
      paths.each do |path|
        get path

        expect(response).to have_http_status(:ok), "expected #{path} to render the form"
        expect_stacked_field_rhythm(response.body, path)
      end
    end

    # Issue #204 — the horizontal rows (a field beside its submit button)
    # align the input's bottom edge with the button's, so they opt out of the
    # bottom rhythm. The opt-out is that row's layout, not a global switch:
    # the stacked surface keeps its rhythm.
    it 'keeps the rhythm on stacked fields and out of the horizontal rows' do
      sign_in_as_owner(organization)
      get api_tokens_index_path
      expect(form_field_class(response.body)).not_to include('mb-4')

      get new_chromosome_path
      expect(form_field_class(response.body)).to include('mb-4')
    end
  end

  # Issue #204 — the auth surfaces are built from the same component, so the
  # convention has to hold there too (anonymous: no session in scope).
  describe 'the auth surfaces' do
    it 'gives every stacked field on the auth forms its own rhythm' do
      [login_path, register_path, '/join', new_user_password_path].each do |path|
        get path

        expect(response).to have_http_status(:ok), "expected #{path} to render the form"
        expect_stacked_field_rhythm(response.body, path)
      end
    end
  end
end
