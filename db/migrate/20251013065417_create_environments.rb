class CreateEnvironments < ActiveRecord::Migration[8.0]
  def change
    create_table :environments do |t|
      t.references :project, null: false, foreign_key: true, index: true
      t.integer :environment_id, null: false
      t.string :name, null: false
      t.string :description
      t.jsonb :metadata, default: {}, null: false

      t.timestamps
    end

    add_index :environments, [:project_id, :environment_id], unique: true
  end
end

