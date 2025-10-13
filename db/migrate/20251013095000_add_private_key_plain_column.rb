class AddPrivateKeyPlainColumn < ActiveRecord::Migration[8.0]
  def change
    add_column :private_keys, :private_key, :text
  end
end



