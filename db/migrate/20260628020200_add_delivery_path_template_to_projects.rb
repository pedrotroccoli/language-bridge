class AddDeliveryPathTemplateToProjects < ActiveRecord::Migration[8.1]
  def change
    # Deterministic Active Storage key template for materialized artifacts.
    # Default is project-scoped so keys stay globally unique across projects.
    add_column :projects, :delivery_path_template, :string,
               null: false, default: "{project_slug}/{namespace}/{locale}.json"
  end
end
