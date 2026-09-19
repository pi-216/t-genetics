# frozen_string_literal: true

module Chromosomes
  # Issue #184 — the machine JSON contract for the nested allele endpoints,
  # pinned by spec/requests/alleles_spec.rb and unchanged by issue #208: the
  # command owns every decision, this concern only renders its result.
  module AllelesMachineApi
    extend ActiveSupport::Concern

    private

    def render_allele_json(result, success_status)
      return render json: result.allele.to_hsh, status: success_status if result.success?

      render json: { errors: result.error_payload }, status: :unprocessable_content
    end
  end
end
