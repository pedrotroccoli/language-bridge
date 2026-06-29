class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings, id: :uuid, default: -> { "uuidv7()" } do |t|
      t.boolean :rate_limiting_enabled, null: false, default: true
      t.integer :missing_rate_limit,    null: false, default: 30
      t.integer :missing_rate_period,   null: false, default: 60
      t.integer :delivery_rate_limit,   null: false, default: 300
      t.integer :delivery_rate_period,  null: false, default: 60

      t.timestamps
    end
  end
end
