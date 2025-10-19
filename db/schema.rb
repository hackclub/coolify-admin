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

ActiveRecord::Schema[8.0].define(version: 2025_10_19_120000) do
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
    t.integer "zombie_processes"
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
    t.integer "zombie_processes"
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

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
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
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "teams", "coolify_teams"
  create_hypertable "resource_stats", time_column: "captured_at", chunk_time_interval: "7 days", compress_segmentby: "resource_id, server_id", compress_orderby: "captured_at DESC", compress_after: "P7D"
  create_hypertable "server_stats", time_column: "captured_at", chunk_time_interval: "7 days", compress_segmentby: "server_id", compress_orderby: "captured_at DESC", compress_after: "P7D"
end
