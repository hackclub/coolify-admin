class AddMemLimitToResourceStats < ActiveRecord::Migration[8.0]
  def change
    add_column :resource_stats, :mem_limit_bytes, :bigint
  end
end
