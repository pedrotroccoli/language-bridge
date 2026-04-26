class CreateSignInTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :sign_in_tokens, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :user, null: false, foreign_key: true, type: :uuid
      t.string :token, null: false
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :sign_in_tokens, :token, unique: true
  end
end
