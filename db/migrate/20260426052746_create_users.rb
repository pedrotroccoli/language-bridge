class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email, null: false
      t.string :role, null: false, default: "translator"

      t.timestamps
    end

    add_index :users, :email, unique: true
  end
end
