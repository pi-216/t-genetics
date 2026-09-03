# frozen_string_literal: true

class ApplicationController < ActionController::Base
  skip_before_action :verify_authenticity_token

  include Identity::Authentication

  private

  # The organization of the signed-in user (nil when anonymous). Every
  # org-scoped query in the app must go through this — never through a
  # bare `Chromosome.find`.
  def current_organization
    @current_organization ||= current_user&.organization
  end

  # Org-scoped chromosome lookup shared by ChromosomesController and the
  # nested Alleles/Generations/Organisms controllers. A chromosome outside the
  # current organization (including anonymous sessions) is indistinguishable
  # from one that does not exist — returns nil, and the caller renders 404
  # (never data — PRD-0002 red line).
  def find_org_chromosome
    Chromosome.where(organization_id: current_organization&.id)
              .find_by(id: params[:chromosome_id] || params[:id])
  end

  # Renders a clean 404 (no exception debug/trace — a cross-org chromosome
  # must never disclose anything) and halts the callback chain.
  def render_org_not_found
    render plain: '', status: :not_found
  end
end
