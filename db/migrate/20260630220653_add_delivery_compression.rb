class AddDeliveryCompression < ActiveRecord::Migration[8.1]
  def change
    # Workspace-wide delivery compression mode: "none", "gzip" or "br".
    add_column :settings, :delivery_compression, :string, default: "gzip", null: false
    # Encoding the stored artifact blob is compressed with (nil = uncompressed).
    add_column :translation_artifacts, :content_encoding, :string
  end
end
