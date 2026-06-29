require "test_helper"

class ProjectBackupFormatTest < ActiveSupport::TestCase
  setup { @project = projects(:main_app) }

  %w[ json csv xliff ].each do |format|
    test "creates and restores a #{format} backup" do
      @project.update!(backup_format: format)

      backup = @project.create_backup!(source: "manual")
      assert backup.file.attached?
      assert_equal format, backup.format
      assert backup.byte_size.positive?

      data = Snapshot.load(backup.file.download, format: backup.format)
      assert_operator TranslationSnapshot.restore(@project, data), :>=, 0
    end
  end

  test "routes the backup to the project's own storage connection" do
    connection = StorageConnection.create!(name: "Proj bucket", service: "local")
    @project.update!(storage_connection: connection)

    backup = @project.create_backup!(source: "manual")
    assert_equal connection.service_key, backup.file.blob.service_name
  end

  test "auto backup is skipped when content is unchanged" do
    @project.create_backup!(source: "auto")
    assert_nil @project.create_backup!(source: "auto")
  end

  test "backup_due? respects the run-at hour" do
    @project.update!(backups_enabled: true, backup_time_of_day: 23)
    travel_to Time.utc(2026, 1, 1, 10, 0, 0) do
      assert_not @project.backup_due?, "not due before the run-at hour"
    end
    travel_to Time.utc(2026, 1, 1, 23, 30, 0) do
      assert @project.backup_due?, "due after the run-at hour"
    end
  end
end
