# frozen_string_literal: true

require 'rails_helper'
require 'rake'

# Finding #149 legacy cleanup (founder ruling 2026-09-13: "delete the old
# test-allele"): chromosomes created before the uniqueness rule carry
# duplicate allele names (observed: "Tip Suggestions" with Bold x2, Tip1 x2,
# ...). The ruling: dedupe by deleting the OLD duplicate allele rows (keep the
# newest per name within a chromosome); values referencing a deleted allele go
# with it (dependent destroy) — verified against the live DB where each
# organism held one value per duplicate row. Idempotent — safe to re-run.
RSpec.describe 'tgenetics:dedupe_duplicate_alleles' do # rubocop:disable RSpec/DescribeClass
  before do
    Rails.application.load_tasks unless Rake::Task.task_defined?('tgenetics:dedupe_duplicate_alleles')
  end

  def run_task
    Rake::Task['tgenetics:dedupe_duplicate_alleles'].reenable
    Rake::Task['tgenetics:dedupe_duplicate_alleles'].invoke
  end

  # The dedupe task exists to clean data that predates the unique DB index
  # (finding #149); its fixture must recreate that pre-index state. Around
  # hooks run inside the example transaction, so the DROP is visible to the
  # fixture, and the example's rollback restores the index — the re-add
  # after is the IF NOT EXISTS safety net for the error path.
  around do |example|
    connection = ActiveRecord::Base.connection
    connection.execute('DROP INDEX IF EXISTS index_alleles_on_chromosome_id_and_name')
    example.run
    connection.execute('CREATE UNIQUE INDEX IF NOT EXISTS index_alleles_on_chromosome_id_and_name ON alleles (chromosome_id, name)')
  end

  # Build legacy duplicate rows the way the bug produced them: two allele rows
  # with the same name on one chromosome, each referenced by organism values.
  # The rows predate the uniqueness rule, so the fixture must bypass the new
  # validation (save(validate: false)) to simulate the pre-fix state the rake
  # task exists to clean up. Both ids are forced explicitly — relying on the
  # sequence for the second row collides nondeterministically when the
  # sequence is at/below oldest_id (the whole alleles table may be empty in a
  # truncated test DB).
  def create_duplicate_pair(chromosome, name, oldest_id:)
    old = Allele.new_with_float(name:, minimum: 0, maximum: 10)
    old.id = oldest_id
    new = Allele.new_with_float(name:, minimum: 0, maximum: 10)
    new.id = oldest_id + 1
    old.chromosome = chromosome
    new.chromosome = chromosome
    old.save(validate: false)
    new.save(validate: false)
    organism = FactoryBot.create(:organism, generation: FactoryBot.create(:generation, chromosome:))
    organism.values << Value.new_from(old) << Value.new_from(new)
    { old:, new: }
  end

  it 'deletes the older duplicate allele and keeps the newest' do
    chromosome = FactoryBot.create(:chromosome)
    pair = create_duplicate_pair(chromosome, 'weight', oldest_id: 1)

    run_task

    expect(Allele.find_by(id: pair[:old].id)).to be_nil
    expect(Allele.find_by(id: pair[:new].id)).to be_present
    expect(chromosome.reload.alleles.map(&:name)).to eq(%w[weight])
  end

  it 'destroys values that referenced the deleted allele (value FK impact)' do
    chromosome = FactoryBot.create(:chromosome)
    pair = create_duplicate_pair(chromosome, 'weight', oldest_id: 1)

    run_task

    expect(Value.where(allele_id: pair[:old].id)).to be_empty
    expect(Value.where(allele_id: pair[:new].id).count).to eq(1)
  end

  it 'leaves unique-name chromosomes untouched' do
    chromosome = FactoryBot.create(:chromosome)
    chromosome.alleles << Allele.new_with_float(name: 'weight', minimum: 0, maximum: 10)
    chromosome.alleles << Allele.new_with_integer(name: 'limbs', minimum: 1, maximum: 4)

    run_task

    expect(chromosome.reload.alleles.map(&:name)).to match_array(%w[weight limbs])
  end

  it 'is idempotent' do
    chromosome = FactoryBot.create(:chromosome)
    create_duplicate_pair(chromosome, 'weight', oldest_id: 1)

    run_task
    run_task

    expect(chromosome.reload.alleles.map(&:name)).to eq(%w[weight])
  end
end
