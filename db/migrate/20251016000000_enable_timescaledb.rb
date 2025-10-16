class EnableTimescaledb < ActiveRecord::Migration[8.0]
  def up
    # Enable TimescaleDB extension
    enable_extension 'timescaledb'
    
    # For server_stats: drop old primary key and create composite key with captured_at
    execute <<-SQL
      ALTER TABLE server_stats DROP CONSTRAINT server_stats_pkey;
    SQL
    
    execute <<-SQL
      ALTER TABLE server_stats ADD PRIMARY KEY (id, captured_at);
    SQL
    
    # Convert server_stats to hypertable
    # Partition by captured_at with 7-day chunks (optimal for time-series data)
    execute <<-SQL
      SELECT create_hypertable(
        'server_stats',
        by_range('captured_at', INTERVAL '7 days'),
        migrate_data => true
      );
    SQL
    
    # For resource_stats: drop old primary key and create composite key with captured_at
    execute <<-SQL
      ALTER TABLE resource_stats DROP CONSTRAINT resource_stats_pkey;
    SQL
    
    execute <<-SQL
      ALTER TABLE resource_stats ADD PRIMARY KEY (id, captured_at);
    SQL
    
    # Convert resource_stats to hypertable
    execute <<-SQL
      SELECT create_hypertable(
        'resource_stats',
        by_range('captured_at', INTERVAL '7 days'),
        migrate_data => true
      );
    SQL
    
    # Add compression policy for server_stats
    # Compress data older than 7 days
    execute <<-SQL
      ALTER TABLE server_stats SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'server_id',
        timescaledb.compress_orderby = 'captured_at DESC'
      );
    SQL
    
    execute <<-SQL
      SELECT add_compression_policy('server_stats', INTERVAL '7 days');
    SQL
    
    # Add compression policy for resource_stats
    # Compress data older than 7 days
    execute <<-SQL
      ALTER TABLE resource_stats SET (
        timescaledb.compress,
        timescaledb.compress_segmentby = 'resource_id,server_id',
        timescaledb.compress_orderby = 'captured_at DESC'
      );
    SQL
    
    execute <<-SQL
      SELECT add_compression_policy('resource_stats', INTERVAL '7 days');
    SQL
  end
  
  def down
    # Remove compression policies
    execute "SELECT remove_compression_policy('server_stats');"
    execute "SELECT remove_compression_policy('resource_stats');"
    
    # Cannot easily revert hypertables to regular tables with data preservation
    # This would require manual data migration
    # For development, dropping and recreating is acceptable
    raise ActiveRecord::IrreversibleMigration, 
          "Cannot automatically revert TimescaleDB hypertables. " \
          "To rollback, you'll need to manually drop and recreate the tables."
  end
end


