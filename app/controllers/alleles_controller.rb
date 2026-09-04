# frozen_string_literal: true

# NOTE: Alleles are now managed within a chromosome scope.
# This controller is intentionally kept as a thin shim for legacy HTML usage.
class AllelesController < ApplicationController
  before_action :require_signed_in

  def index
    head :not_found
  end

  def show
    head :not_found
  end

  def new
    head :not_found
  end

  def edit
    head :not_found
  end

  def create
    head :not_found
  end

  def update
    head :not_found
  end

  def destroy
    head :not_found
  end
end
