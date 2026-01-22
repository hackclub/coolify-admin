class UpdateCompressionPolicyFrequency < ActiveRecord::Migration[8.0]
  def up
    # Remove old compression policies (compress after 7 days)
    execute "SELECT remove_compression_policy('server_stats');"
    execute "SELECT remove_compression_policy('resource_stats');"

    # Add new compression policies (compress after 1 hour, run every hour)
    execute <<-SQL
      SELECT add_compression_policy('server_stats', INTERVAL '1 hour', schedule_interval => INTERVAL '1 hour');
    SQL

    execute <<-SQL
      SELECT add_compression_policy('resource_stats', INTERVAL '1 hour', schedule_interval => INTERVAL '1 hour');
    SQL
  end

  def down
    # Remove 1 hour compression policies
    execute "SELECT remove_compression_policy('server_stats');"
    execute "SELECT remove_compression_policy('resource_stats');"

    # Restore original 7 day compression policies
    execute <<-SQL
      SELECT add_compression_policy('server_stats', INTERVAL '7 days');
    SQL

    execute <<-SQL
      SELECT add_compression_policy('resource_stats', INTERVAL '7 days');
    SQL
  end
end
