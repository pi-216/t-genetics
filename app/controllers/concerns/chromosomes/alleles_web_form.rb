# frozen_string_literal: true

module Chromosomes
  # Issue #208 — the browser transport half of the nested allele controller.
  # The mutations themselves live in Chromosomes::Alleles::Create/Update now, so
  # this concern only answers "is this the browser form?" and re-renders the
  # form with the command's errors. The form's view helpers (field errors, the
  # type → partial maps) live in AllelesHelper.
  module AllelesWebForm
    extend ActiveSupport::Concern

    private

    # Web requests carry a browser Accept starting with text/html; everything
    # else (format-less machine specs, */* clients, application/json) keeps
    # the pre-existing unconditional-JSON behavior — the machine contract is
    # pinned by alleles_spec.rb and must not depend on Accept quirks. An
    # explicit ?format=html also selects the browser branch.
    def html_request?
      request.headers['HTTP_ACCEPT'].to_s.lstrip.start_with?('text/html') ||
        request.params[:format].to_s == 'html'
    end

    def render_allele_form(template)
      render template, status: :unprocessable_content
    end
  end
end
