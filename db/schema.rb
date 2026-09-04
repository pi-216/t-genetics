# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_04_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "alleles", force: :cascade do |t|
    t.bigint "chromosome_id", null: false
    t.datetime "created_at", null: false
    t.integer "inheritable_id", null: false
    t.string "inheritable_type", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.index ["chromosome_id"], name: "index_alleles_on_chromosome_id"
  end

  create_table "api_tokens", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "last_used_at"
    t.string "name", null: false
    t.bigint "organization_id", null: false
    t.datetime "revoked_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_api_tokens_on_organization_id"
    t.index ["token_digest"], name: "index_api_tokens_on_token_digest", unique: true
  end

  create_table "boolean_alleles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "boolean_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "data"
    t.datetime "updated_at", null: false
  end

  create_table "chromosomes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "organization_id"
    t.datetime "updated_at", null: false
    t.index ["organization_id"], name: "index_chromosomes_on_organization_id"
  end

  create_table "experiments", force: :cascade do |t|
    t.bigint "chromosome_id", null: false
    t.jsonb "configuration", default: {}, null: false
    t.datetime "created_at", null: false
    t.bigint "current_generation_id"
    t.string "external_entity_id"
    t.string "external_entity_type"
    t.float "feedback_percentage_threshold", default: 0.75, null: false
    t.integer "min_organisms_with_feedback", default: 2, null: false
    t.string "status"
    t.float "suggestion_count_threshold_multiplier", default: 3.0, null: false
    t.datetime "updated_at", null: false
    t.index ["chromosome_id"], name: "index_experiments_on_chromosome_id"
    t.index ["current_generation_id"], name: "index_experiments_on_current_generation_id"
    t.index ["external_entity_id", "external_entity_type"], name: "index_experiments_on_external_entity"
  end

  create_table "float_alleles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "maximum", default: 1.0, null: false
    t.float "minimum", default: 0.0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "float_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "data"
    t.datetime "updated_at", null: false
  end

  create_table "generations", force: :cascade do |t|
    t.bigint "chromosome_id", null: false
    t.datetime "created_at", null: false
    t.integer "iteration", default: -1, null: false
    t.datetime "updated_at", null: false
    t.index ["chromosome_id"], name: "index_generations_on_chromosome_id"
  end

  create_table "integer_alleles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "maximum", default: 100, null: false
    t.integer "minimum", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "integer_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "data"
    t.datetime "updated_at", null: false
  end

  create_table "invite_codes", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_invite_codes_on_code", unique: true
    t.index ["organization_id"], name: "index_invite_codes_on_organization_id", unique: true
  end

  create_table "option_alleles", force: :cascade do |t|
    t.json "choices", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "option_values", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "data"
    t.datetime "updated_at", null: false
  end

  create_table "org_memberships", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "organization_id", null: false
    t.string "role", default: "member", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["organization_id"], name: "index_org_memberships_on_organization_id"
    t.index ["user_id"], name: "index_org_memberships_on_user_id", unique: true
  end

  create_table "organisms", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "fitness"
    t.bigint "generation_id", null: false
    t.datetime "updated_at", null: false
    t.index ["generation_id"], name: "index_organisms_on_generation_id"
  end

  create_table "organizations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_organizations_on_name", unique: true
  end

  create_table "performance_logs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "experiment_id", null: false
    t.float "fitness_input_value"
    t.bigint "organism_id", null: false
    t.jsonb "outcome_metrics"
    t.datetime "outcome_recorded_at"
    t.datetime "suggested_at", null: false
    t.datetime "updated_at", null: false
    t.index ["experiment_id"], name: "index_performance_logs_on_experiment_id"
    t.index ["organism_id"], name: "index_performance_logs_on_organism_id"
  end

  create_table "relationships", force: :cascade do |t|
    t.bigint "child_id", null: false
    t.datetime "created_at", null: false
    t.bigint "parent_id", null: false
    t.datetime "updated_at", null: false
    t.index ["child_id"], name: "index_relationships_on_child_id"
    t.index ["parent_id"], name: "index_relationships_on_parent_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "values", force: :cascade do |t|
    t.bigint "allele_id", null: false
    t.datetime "created_at", null: false
    t.bigint "organism_id", null: false
    t.datetime "updated_at", null: false
    t.integer "valuable_id"
    t.string "valuable_type"
    t.index ["allele_id"], name: "index_values_on_allele_id"
    t.index ["organism_id"], name: "index_values_on_organism_id"
  end

  add_foreign_key "alleles", "chromosomes"
  add_foreign_key "api_tokens", "organizations"
  add_foreign_key "chromosomes", "organizations"
  add_foreign_key "experiments", "chromosomes"
  add_foreign_key "experiments", "generations", column: "current_generation_id"
  add_foreign_key "generations", "chromosomes"
  add_foreign_key "invite_codes", "organizations"
  add_foreign_key "org_memberships", "organizations"
  add_foreign_key "org_memberships", "users"
  add_foreign_key "organisms", "generations"
  add_foreign_key "performance_logs", "experiments"
  add_foreign_key "performance_logs", "organisms"
  add_foreign_key "relationships", "chromosomes", column: "child_id"
  add_foreign_key "relationships", "chromosomes", column: "parent_id"
  add_foreign_key "values", "alleles"
  add_foreign_key "values", "organisms"
end
