class CreateTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :teams do |t|
      t.references :coolify_team, null: false, foreign_key: true, index: true
      t.integer :team_id, null: false
      t.string :name, null: false
      t.string :description
      t.boolean :personal_team, default: false
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :teams, [:coolify_team_id, :team_id], unique: true
  end
end

