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

ActiveRecord::Schema[8.0].define(version: 2025_10_12_190000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "coolify_teams", force: :cascade do |t|
    t.string "name", null: false
    t.string "base_url", null: false
    t.string "api_path_prefix", default: "", null: false
    t.text "token", null: false
    t.string "token_fingerprint", null: false
    t.string "team_uuid"
    t.boolean "verify_tls", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["base_url", "team_uuid"], name: "idx_coolify_team_host_teamuuid", unique: true
    t.index ["token_fingerprint"], name: "index_coolify_teams_on_token_fingerprint", unique: true
  end
end
