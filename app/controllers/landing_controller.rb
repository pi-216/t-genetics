# frozen_string_literal: true

# Public landing page (PRD-0001) — the product front door. Public route: no
# auth, no org context, no DB access. Brand-neutral first pass; design-sprint
# tokens land later as a mechanical restyle (feature drift flag).
class LandingController < ApplicationController
  def show; end
end
