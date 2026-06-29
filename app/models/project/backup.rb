# One cloud backup of a project's translations: a JSON snapshot stored in the
# configured Active Storage service (S3/GCS when set, Disk otherwise). Created on
# demand or by the scheduled BackupProjectJob; oldest beyond KEEP are pruned.
class Project::Backup < ApplicationRecord
  self.table_name = "project_backups"

  belongs_to :project

  # The snapshot file; purged with the record.
  has_one_attached :file

  scope :recent, -> { order(created_at: :desc) }
end
