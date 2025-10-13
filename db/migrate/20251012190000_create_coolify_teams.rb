class CreateCoolifyTeams < ActiveRecord::Migration[8.0]
  def change
    create_table :coolify_teams do |t|
      t.string  :name,              null: false
      t.string  :base_url,          null: false
      t.string  :api_path_prefix,   null: false, default: ""   # leave blank; service can auto-detect
      t.text    :token,             null: false                # Rails encrypted attribute storage (stores ciphertext)
      t.string  :token_fingerprint, null: false                # SHA-256 of plaintext token
      t.string  :team_uuid                                     # optional; fill after probing
      t.boolean :verify_tls,        null: false, default: true
      t.timestamps
    end

    add_index :coolify_teams, :token_fingerprint, unique: true
    add_index :coolify_teams, [:base_url, :team_uuid],
              unique: true, name: "idx_coolify_team_host_teamuuid"
  end
end

