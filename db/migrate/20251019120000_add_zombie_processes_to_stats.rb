class AddZombieProcessesToStats < ActiveRecord::Migration[8.0]
  def change
    add_column :server_stats, :zombie_processes, :integer
    add_column :resource_stats, :zombie_processes, :integer
  end
end

