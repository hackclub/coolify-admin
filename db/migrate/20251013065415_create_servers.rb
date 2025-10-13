class CreateServers < ActiveRecord::Migration[8.0]
  def change
    create_table :servers do |t|
      t.references :coolify_team, null: false, foreign_key: true, index: true
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :description
      t.string :ip
      t.integer :port
      t.string :user
      t.string :proxy_type
      t.boolean :is_reachable, default: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :servers, [:coolify_team_id, :uuid], unique: true
    add_index :servers, :uuid
  end
end

