class AddCpuCoresToServers < ActiveRecord::Migration[8.0]
  def change
    add_column :servers, :cpu_cores, :integer
  end
end
