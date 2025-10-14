class AddPrivateKeyToServers < ActiveRecord::Migration[8.0]
  def change
    add_reference :servers, :private_key, foreign_key: true, index: true
  end
end







