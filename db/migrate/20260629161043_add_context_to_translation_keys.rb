class AddContextToTranslationKeys < ActiveRecord::Migration[8.1]
  def change
    add_column :translation_keys, :context, :text
  end
end
