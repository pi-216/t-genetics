# frozen_string_literal: true

# Finding #149: allele names are unique within a chromosome. The model
# validates scoped uniqueness; this index enforces it at the DB layer so no
# write path (designer command, append API, machine API, backfill) can ever
# re-introduce the duplication observed in stored data.
#
# Run `bin/rails tgenetics:dedupe_duplicate_alleles` BEFORE this migration on
# any environment whose alleles table carries legacy duplicate rows (the
# index addition fails on duplicates, by design — that is the guarantee).
class AddUniqueIndexOnAllelesChromosomeName < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_index :alleles, %i[chromosome_id name], unique: true, name: 'index_alleles_on_chromosome_id_and_name', algorithm: :concurrently
  end
end
