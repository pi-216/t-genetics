# frozen_string_literal: true

# Data backfill (finding #56, founder ruling 2026-09-04): chromosomes created
# before org-scoping carried organization_id IS NULL and were visible to
# anonymous sessions. Ruling: MIGRATE legacy rows to a seed org via rake task
# (do not purge). Idempotent — safe to re-run; leaves org-scoped rows alone.
SEED_ORG_NAME = 'Legacy Seed'

namespace :tgenetics do
  desc 'Migrate legacy org-less chromosomes to the "Legacy Seed" org (finding #56)'
  task migrate_legacy_org_rows: :environment do
    legacy_rows = Chromosome.where(organization_id: nil)
    count = legacy_rows.count

    if count.zero?
      puts 'No legacy org-less chromosomes found — nothing to migrate.'
      next
    end

    seed_org = Identity::Organization.find_or_create_by!(name: SEED_ORG_NAME)
    migrated = 0
    legacy_rows.find_each do |chromosome|
      chromosome.update!(organization: seed_org)
      migrated += 1
    end

    puts "Migrated #{migrated} legacy chromosome(s) to #{SEED_ORG_NAME} (org ##{seed_org.id})."
  end
end
