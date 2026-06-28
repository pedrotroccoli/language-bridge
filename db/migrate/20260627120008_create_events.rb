class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.string :eventable_type, null: false
      t.uuid :eventable_id, null: false
      t.string :action, null: false
      t.references :creator, null: true, foreign_key: { to_table: :users }, type: :uuid, index: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :events, [ :eventable_type, :eventable_id ]
    add_index :events, [ :creator_id, :created_at ]
    add_index :events, :created_at
  end
end
