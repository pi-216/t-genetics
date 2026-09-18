# frozen_string_literal: true

module Chromosomes
  # Issue #207 — the command behind ChromosomesController#update (AGENTS.md
  # command pattern: auth → validate → call command → render; a mutation never
  # lands as a raw model write in the controller). Mirrors Chromosomes::Create:
  # one GLCommand result shape for every transport, and the organization is a
  # required argument rather than a controller-wide default — a chromosome the
  # organization does not own fails instead of writing (PRD-0002 red line).
  class Update < ApplicationCommand
    requires :chromosome, organization: Identity::Organization
    allows :name
    returns chromosome: Chromosome

    def call
      context.chromosome = chromosome

      fail_command!(errors: { chromosome: ['does not belong to this organization'] }) unless owned_by_organization?

      return if chromosome.update(name: name)

      fail_command!(errors: chromosome.errors)
    end

    private

    def owned_by_organization?
      chromosome.organization_id == organization.id
    end
  end
end
