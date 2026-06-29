# Fan out a per-project backup. Wired to a recurring schedule (config/recurring.yml)
# so every project is snapshotted to the cloud periodically.
class BackupAllProjectsJob < ApplicationJob
  queue_as :default

  def perform
    Project.where(backups_enabled: true).find_each do |project|
      BackupProjectJob.perform_later(project, source: "auto") if project.backup_due?
    end
  end
end
