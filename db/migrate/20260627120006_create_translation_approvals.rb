class CreateTranslationApprovals < ActiveRecord::Migration[8.1]
  def change
    create_table :translation_approvals, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.references :translation, null: false, foreign_key: true, type: :uuid, index: false
      t.references :approver, null: false, foreign_key: { to_table: :users }, type: :uuid

      t.timestamps
    end

    add_index :translation_approvals, :translation_id, unique: true
  end
end
