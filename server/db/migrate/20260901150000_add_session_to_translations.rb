class AddSessionToTranslations < ActiveRecord::Migration[8.1]
  def change
    # A CLI push writes real draft translations tagged with the session that
    # produced them (git branch or AI chat), so parallel work streams show up in
    # the editor as separate reviewable groups of Unpublished rows.
    add_column :translations, :session, :string
    add_index :translations, :session
  end
end
