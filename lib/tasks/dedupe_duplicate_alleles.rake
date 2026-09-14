# frozen_string_literal: true

# Legacy data cleanup (finding #149, founder ruling 2026-09-13: "delete the
# old test-allele"): chromosomes created before the scoped-uniqueness rule
# carry duplicate allele names (observed: "Tip Suggestions" with Bold x2,
# Tip1 x2, Tip2 x2, Unit x2). The ruling: dedupe by deleting the OLDER
# duplicate allele rows — keep the newest per name within a chromosome;
# values that referenced a deleted allele go with it (dependent destroy,
# verified against live data where each organism held one value per
# duplicate row). Idempotent — safe to re-run; leaves unique rows alone.
namespace :tgenetics do
  desc 'Delete duplicate allele rows per chromosome, keeping the newest (finding #149)'
  task dedupe_duplicate_alleles: :environment do
    duplicate_groups = Allele.group(:chromosome_id, :name).having('count(*) > 1').count
    total_groups = duplicate_groups.size

    if total_groups.zero?
      puts 'No duplicate allele names found — nothing to dedupe.'
      next
    end

    deleted = 0
    duplicate_groups.each_key do |chromosome_id, name|
      dupes = Allele.where(chromosome_id:, name:).order(:created_at, :id)
      keeper = dupes.last
      duplicate_count = dupes.size
      dupes.where.not(id: keeper.id).find_each do |allele|
        allele.destroy! # values go with it (dependent: :destroy)
        deleted += 1
      end
      puts "chromosome ##{chromosome_id} '#{name}': kept allele ##{keeper.id}, deleted #{duplicate_count - 1} older copy(ies)"
    end

    puts "Deduplicated #{total_groups} name group(s); deleted #{deleted} duplicate allele row(s)."
  end
end
