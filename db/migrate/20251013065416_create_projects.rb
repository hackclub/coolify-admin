class CreateProjects < ActiveRecord::Migration[8.0]
  def change
    create_table :projects do |t|
      t.references :coolify_team, null: false, foreign_key: true, index: true
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :description
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :projects, [:coolify_team_id, :uuid], unique: true
    add_index :projects, :uuid
  end
end

