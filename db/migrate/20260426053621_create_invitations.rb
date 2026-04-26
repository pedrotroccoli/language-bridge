class CreateInvitations < ActiveRecord::Migration[8.1]
  def change
    create_table :invitations, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :email, null: false
      t.string :role, null: false
      t.string :token, null: false
      t.references :inviter, null: false, foreign_key: { to_table: :users }, type: :uuid
      t.datetime :expires_at, null: false
      t.datetime :accepted_at

      t.timestamps
    end

    add_index :invitations, :token, unique: true
    add_index :invitations, :email, unique: true, where: "accepted_at IS NULL"
  end
end
