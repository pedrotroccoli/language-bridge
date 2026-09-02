class CreateCliAuthCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :cli_auth_codes, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.uuid :user_id, null: false
      t.string :code_digest, null: false
      t.string :name, null: false
      t.datetime :expires_at, null: false
      t.datetime :used_at
      t.timestamps
    end

    add_index :cli_auth_codes, :code_digest, unique: true
    add_index :cli_auth_codes, :user_id
    add_foreign_key :cli_auth_codes, :users
  end
end
