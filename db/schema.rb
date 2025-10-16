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

ActiveRecord::Schema[8.0].define(version: 2025_10_16_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "timescaledb"

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

  create_table "private_keys", force: :cascade do |t|
    t.bigint "coolify_team_id", null: false
    t.string "uuid"
    t.string "name"
    t.string "fingerprint"
    t.string "source", default: "manual", null: false
    t.text "private_key_ciphertext"
    t.datetime "last_fetched_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "private_key"
    t.index ["coolify_team_id", "name"], name: "index_private_keys_on_coolify_team_id_and_name"
    t.index ["coolify_team_id", "uuid"], name: "index_private_keys_on_coolify_team_id_and_uuid", unique: true
    t.index ["coolify_team_id"], name: "index_private_keys_on_coolify_team_id"
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

  create_table "resource_stats", primary_key: ["id", "captured_at"], force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "resource_id", null: false
    t.bigint "server_id", null: false
    t.datetime "captured_at", null: false
    t.float "cpu_pct"
    t.float "mem_pct"
    t.bigint "mem_used_bytes"
    t.bigint "disk_persistent_bytes"
    t.bigint "disk_runtime_bytes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "mem_limit_bytes"
    t.index ["captured_at"], name: "resource_stats_captured_at_idx", order: :desc
    t.index ["resource_id", "captured_at"], name: "index_resource_stats_on_resource_id_and_captured_at"
    t.index ["resource_id"], name: "index_resource_stats_on_resource_id"
    t.index ["server_id"], name: "index_resource_stats_on_server_id"
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

  create_table "server_stats", primary_key: ["id", "captured_at"], force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "server_id", null: false
    t.datetime "captured_at", null: false
    t.float "cpu_pct"
    t.float "mem_pct"
    t.bigint "mem_used_bytes"
    t.bigint "disk_used_bytes"
    t.bigint "disk_total_bytes"
    t.float "iops_r"
    t.float "iops_w"
    t.float "load1"
    t.float "load5"
    t.float "load15"
    t.jsonb "filesystems", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["captured_at"], name: "server_stats_captured_at_idx", order: :desc
    t.index ["server_id", "captured_at"], name: "index_server_stats_on_server_id_and_captured_at"
    t.index ["server_id"], name: "index_server_stats_on_server_id"
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
    t.bigint "private_key_id"
    t.integer "cpu_cores"
    t.index ["coolify_team_id", "uuid"], name: "index_servers_on_coolify_team_id_and_uuid", unique: true
    t.index ["coolify_team_id"], name: "index_servers_on_coolify_team_id"
    t.index ["private_key_id"], name: "index_servers_on_private_key_id"
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
  add_foreign_key "private_keys", "coolify_teams"
  add_foreign_key "projects", "coolify_teams"
  add_foreign_key "resource_stats", "resources"
  add_foreign_key "resource_stats", "servers"
  add_foreign_key "resources", "coolify_teams"
  add_foreign_key "resources", "environments"
  add_foreign_key "resources", "servers"
  add_foreign_key "server_stats", "servers"
  add_foreign_key "servers", "coolify_teams"
  add_foreign_key "servers", "private_keys"
  add_foreign_key "teams", "coolify_teams"
  create_hypertable "resource_stats", time_column: "captured_at", chunk_time_interval: "7 days", compress_segmentby: "resource_id, server_id", compress_orderby: "captured_at DESC", compress_after: "P7D"
  create_hypertable "server_stats", time_column: "captured_at", chunk_time_interval: "7 days", compress_segmentby: "server_id", compress_orderby: "captured_at DESC", compress_after: "P7D"
end
