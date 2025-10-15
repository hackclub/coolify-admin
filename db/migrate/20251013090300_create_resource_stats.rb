class CreateResourceStats < ActiveRecord::Migration[8.0]
  def change
    create_table :resource_stats do |t|
      t.references :resource, null: false, foreign_key: true, index: true
      t.references :server, null: false, foreign_key: true, index: true
      t.datetime :captured_at, null: false
      t.float :cpu_pct
      t.float :mem_pct
      t.bigint :mem_used_bytes
      t.bigint :disk_persistent_bytes
      t.bigint :disk_runtime_bytes
      t.bigint :disk_logs_bytes

      t.timestamps
    end

    add_index :resource_stats, [:resource_id, :captured_at]
  end
end