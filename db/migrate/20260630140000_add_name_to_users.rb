class AddNameToUsers < ActiveRecord::Migration[8.1]
  def change
    # Optional display name; falls back to the email local-part when blank.
    # The avatar is an Active Storage attachment (tables already exist).
    add_column :users, :name, :string
  end
end
