class CreateServerStats < ActiveRecord::Migration[8.0]
  def change
    create_table :server_stats do |t|
      t.references :server, null: false, foreign_key: true, index: true
      t.datetime :captured_at, null: false
      t.float :cpu_pct
      t.float :mem_pct
      t.bigint :mem_used_bytes
      t.bigint :disk_used_bytes
      t.bigint :disk_total_bytes
      t.float :iops_r
      t.float :iops_w
      t.float :load1
      t.float :load5
      t.float :load15
      t.jsonb :filesystems, null: false, default: []

      t.timestamps
    end

    add_index :server_stats, [:server_id, :captured_at]
  end
end






