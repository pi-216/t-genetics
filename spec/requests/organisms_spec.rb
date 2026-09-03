# frozen_string_literal: true

require 'rails_helper'

RSpec.describe "Organisms", type: :request do
  describe "GET /chromosomes/:chromosome_id/generations/:generation_id/organisms" do
    let(:organization) { FactoryBot.create(:organization) }
    let(:user) { sign_in_as(organization: organization) }
    let(:chromosome) { FactoryBot.create(:chromosome, organization: organization) }
    let(:generation) { FactoryBot.create(:generation, chromosome: chromosome) }
    let!(:organism) { Organisms::Create.call(generation: generation).organism }

    before { user }

    it "includes the id in the response" do
      get chromosome_generation_organisms_path(chromosome, generation), headers: { 'ACCEPT' => 'application/json' }
      
      expect(response).to have_http_status(:success)
      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first).to have_key("id")
      expect(json_response.first["id"]).to eq(organism.id)
    end
  end
end
