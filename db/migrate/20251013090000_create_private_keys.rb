class CreatePrivateKeys < ActiveRecord::Migration[8.0]
  def change
    create_table :private_keys do |t|
      t.references :coolify_team, null: false, foreign_key: true, index: true
      t.string :uuid
      t.string :name
      t.string :fingerprint
      t.string :source, null: false, default: 'manual'
      t.text :private_key_ciphertext
      t.datetime :last_fetched_at

      t.timestamps
    end

    add_index :private_keys, [:coolify_team_id, :uuid], unique: true
    add_index :private_keys, [:coolify_team_id, :name]
  end
end