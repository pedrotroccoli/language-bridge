class AddDeliveryBaseUrlToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :delivery_base_url, :string, null: false, default: ""
  end
end
