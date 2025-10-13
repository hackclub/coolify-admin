class RemoveDiskLogsBytesFromResourceStats < ActiveRecord::Migration[8.0]
  def change
    remove_column :resource_stats, :disk_logs_bytes, :bigint
  end
end
