# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chromosomes::AllelesController do
  describe 'routing' do
    it 'does not expose top-level alleles' do
      expect(get: '/alleles').not_to be_routable
    end

    it 'routes to #index' do
      expect(get: '/chromosomes/1/alleles').to route_to('chromosomes/alleles#index', chromosome_id: '1')
    end

    it 'routes to #show' do
      expect(get: '/chromosomes/1/alleles/2').to route_to('chromosomes/alleles#show', chromosome_id: '1', id: '2')
    end

    # Issue #184 — standard CRUD: the web allele forms became routable.
    it 'routes to #new' do
      expect(get: '/chromosomes/1/alleles/new').to route_to('chromosomes/alleles#new', chromosome_id: '1')
    end

    it 'routes to #edit' do
      expect(get: '/chromosomes/1/alleles/2/edit').to route_to('chromosomes/alleles#edit', chromosome_id: '1', id: '2')
    end

    it 'routes to #create' do
      expect(post: '/chromosomes/1/alleles').to route_to('chromosomes/alleles#create', chromosome_id: '1')
    end

    it 'routes to #update via PATCH' do
      expect(patch: '/chromosomes/1/alleles/2').to route_to('chromosomes/alleles#update', chromosome_id: '1', id: '2')
    end

    it 'routes to #destroy' do
      expect(delete: '/chromosomes/1/alleles/2').to route_to('chromosomes/alleles#destroy', chromosome_id: '1', id: '2')
    end
  end
end
