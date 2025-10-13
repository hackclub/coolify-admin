class CreateResources < ActiveRecord::Migration[8.0]
  def change
    create_table :resources do |t|
      # STI discriminator
      t.string :type, null: false, index: true
      
      # Foreign keys
      t.references :coolify_team, null: false, foreign_key: true, index: true
      t.references :server, null: false, foreign_key: true, index: true
      t.references :environment, null: false, foreign_key: true, index: true
      
      # Common fields
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :description
      t.string :status
      t.string :fqdn
      
      # Metadata for type-specific fields
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    # Indexes for common queries
    add_index :resources, [:coolify_team_id, :uuid], unique: true
    add_index :resources, :uuid
    add_index :resources, :status
    add_index :resources, [:type, :status]
    add_index :resources, [:server_id, :type]
  end
end

