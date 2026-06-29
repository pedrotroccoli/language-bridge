require "test_helper"

class Projects::BackupsControllerTest < ActionDispatch::IntegrationTest
  setup { @project = projects(:main_app) }

  test "admin sees the backups tab" do
    sign_in_as(users(:admin))
    get project_backups_path(@project)
    assert_response :success
    assert_select "h2", "Backups"
  end

  test "admin backs up now" do
    sign_in_as(users(:admin))
    assert_difference -> { @project.backups.count }, 1 do
      post project_backups_path(@project)
    end
    assert_redirected_to project_backups_path(@project)
    assert_equal "manual", @project.backups.recent.first.source
  end

  test "admin saves the backup schedule" do
    sign_in_as(users(:admin))
    patch project_backup_schedule_path(@project), params: { project: {
      backups_enabled: "1", backup_frequency: "weekly", backup_retention: 10, backup_include_drafts: "1"
    } }
    assert_redirected_to project_backups_path(@project)
    @project.reload
    assert_equal "weekly", @project.backup_frequency
    assert_equal 10, @project.backup_retention
    assert @project.backup_include_drafts
  end

  test "admin restores from a backup" do
    sign_in_as(users(:admin))
    BackupProjectJob.perform_now(@project)
    backup = @project.backups.recent.first

    post project_backup_restoration_path(@project, backup)
    assert_redirected_to project_backups_path(@project)
  end

  test "non-admin cannot back up" do
    sign_in_as(users(:translator))
    post project_backups_path(@project)
    assert_response :forbidden
  end

  test "restore rejects a tampered snapshot instead of crashing" do
    sign_in_as(users(:admin))
    BackupProjectJob.perform_now(@project)
    backup = @project.backups.recent.first
    backup.update_column(:checksum, "deadbeef") # corrupt the recorded checksum

    post project_backup_restoration_path(@project, backup)
    assert_redirected_to project_backups_path(@project)
    assert_match(/integrity check failed/i, flash[:alert])
  end
end
