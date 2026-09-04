# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# Legacy org-less row migration (finding #56, founder ruling 2026-09-04):
# chromosomes created before org-scoping carry organization_id IS NULL. The
# ruling: MIGRATE them to a seed org via rake task (do not purge). The task
# is idempotent and safe to re-run.
RSpec.describe 'tgenetics:migrate_legacy_org_rows' do # rubocop:disable RSpec/DescribeClass
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('tgenetics:migrate_legacy_org_rows')
  end

  def run_task
    Rake::Task['tgenetics:migrate_legacy_org_rows'].reenable
    Rake::Task['tgenetics:migrate_legacy_org_rows'].invoke
  end

  it 'moves org-less chromosomes to a seed org' do
    legacy = FactoryBot.create(:chromosome, name: 'legacy-1', organization: nil)

    expect { run_task }.to change { legacy.reload.organization_id }.from(nil).to(be_present)

    seed_org = Identity::Organization.find_by(name: described_seed_org_name)
    expect(seed_org).to be_present
    expect(legacy.reload.organization).to eq(seed_org)
  end

  it 'does not touch chromosomes that already belong to an org' do
    org = FactoryBot.create(:organization, name: 'Owner Org')
    scoped = FactoryBot.create(:chromosome, name: 'scoped-1', organization: org)

    run_task

    expect(scoped.reload.organization).to eq(org)
  end

  it 'is idempotent' do
    FactoryBot.create(:chromosome, name: 'legacy-2', organization: nil)

    run_task
    run_task

    expect(Identity::Organization.where(name: described_seed_org_name).count).to eq(1)
    expect(Chromosome.where(organization_id: nil).count).to eq(0)
  end

  def described_seed_org_name
    'Legacy Seed'
  end
end
