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

ActiveRecord::Schema[8.0].define(version: 2025_10_13_065418) do
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

  create_table "environments", force: :cascade do |t|
    t.bigint "project_id", null: false
    t.integer "environment_id", null: false
    t.string "name", null: false
    t.string "description"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["project_id", "environment_id"], name: "index_environments_on_project_id_and_environment_id", unique: true
    t.index ["project_id"], name: "index_environments_on_project_id"
  end

  create_table "projects", force: :cascade do |t|
    t.bigint "coolify_team_id", null: false
    t.string "uuid", null: false
    t.string "name", null: false
    t.string "description"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coolify_team_id", "uuid"], name: "index_projects_on_coolify_team_id_and_uuid", unique: true
    t.index ["coolify_team_id"], name: "index_projects_on_coolify_team_id"
    t.index ["uuid"], name: "index_projects_on_uuid"
  end

  create_table "resources", force: :cascade do |t|
    t.string "type", null: false
    t.bigint "coolify_team_id", null: false
    t.bigint "server_id", null: false
    t.bigint "environment_id", null: false
    t.string "uuid", null: false
    t.string "name", null: false
    t.string "description"
    t.string "status"
    t.string "fqdn"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coolify_team_id", "uuid"], name: "index_resources_on_coolify_team_id_and_uuid", unique: true
    t.index ["coolify_team_id"], name: "index_resources_on_coolify_team_id"
    t.index ["environment_id"], name: "index_resources_on_environment_id"
    t.index ["server_id", "type"], name: "index_resources_on_server_id_and_type"
    t.index ["server_id"], name: "index_resources_on_server_id"
    t.index ["status"], name: "index_resources_on_status"
    t.index ["type", "status"], name: "index_resources_on_type_and_status"
    t.index ["type"], name: "index_resources_on_type"
    t.index ["uuid"], name: "index_resources_on_uuid"
  end

  create_table "servers", force: :cascade do |t|
    t.bigint "coolify_team_id", null: false
    t.string "uuid", null: false
    t.string "name", null: false
    t.string "description"
    t.string "ip"
    t.integer "port"
    t.string "user"
    t.string "proxy_type"
    t.boolean "is_reachable", default: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coolify_team_id", "uuid"], name: "index_servers_on_coolify_team_id_and_uuid", unique: true
    t.index ["coolify_team_id"], name: "index_servers_on_coolify_team_id"
    t.index ["uuid"], name: "index_servers_on_uuid"
  end

  create_table "teams", force: :cascade do |t|
    t.bigint "coolify_team_id", null: false
    t.integer "team_id", null: false
    t.string "name", null: false
    t.string "description"
    t.boolean "personal_team", default: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["coolify_team_id", "team_id"], name: "index_teams_on_coolify_team_id_and_team_id", unique: true
    t.index ["coolify_team_id"], name: "index_teams_on_coolify_team_id"
  end

  add_foreign_key "environments", "projects"
  add_foreign_key "projects", "coolify_teams"
  add_foreign_key "resources", "coolify_teams"
  add_foreign_key "resources", "environments"
  add_foreign_key "resources", "servers"
  add_foreign_key "servers", "coolify_teams"
  add_foreign_key "teams", "coolify_teams"
end
