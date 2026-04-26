class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.string :user_agent
      t.string :ip_address

      t.timestamps
    end

    add_index :sessions, :token, unique: true
  end
end
