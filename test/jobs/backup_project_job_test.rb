require "test_helper"

class BackupProjectJobTest < ActiveJob::TestCase
  test "creates a backup with an attached snapshot at a readable key" do
    project = projects(:main_app)

    assert_difference -> { project.backups.count }, 1 do
      BackupProjectJob.perform_now(project)
    end

    backup = project.backups.recent.first
    assert backup.file.attached?
    assert_equal "application/json", backup.file.content_type
    assert backup.byte_size.positive?
    assert_equal project.translations.count, backup.translations_count
    assert_match %r{\Abackups/main-app/\d{8}-\d{6}-}, backup.file.key
  end

  test "routes the snapshot to the default storage connection's service" do
    project = projects(:main_app)
    StorageConnection.create!(name: "Local bucket", service_name: "local", is_default: true)

    BackupProjectJob.perform_now(project)

    assert_equal "local", project.backups.recent.first.file.blob.service_name
  end

  test "prunes backups beyond the per-project retention limit" do
    project = projects(:main_app)
    project.update!(backup_retention: 1)

    BackupProjectJob.perform_now(project)
    BackupProjectJob.perform_now(project)

    assert_equal 1, project.backups.count
  end
end
