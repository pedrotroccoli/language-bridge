require "test_helper"

class BackupAllProjectsJobTest < ActiveJob::TestCase
  # Freeze to an hour past the projects' backup_time_of_day (UTC) so the
  # time-of-day gate in #backup_due? holds no matter when CI runs.
  test "enqueues an auto backup only for enabled, due projects" do
    travel_to Time.utc(2026, 6, 1, 23) do
      due = projects(:main_app)
      disabled = projects(:marketing_site)
      disabled.update!(backups_enabled: false)

      assert_enqueued_with(job: BackupProjectJob, args: [ due, { source: "auto" } ]) do
        BackupAllProjectsJob.perform_now
      end

      # A project backed up moments ago (within its interval) is not due again.
      BackupProjectJob.perform_now(due, source: "auto")
      assert_no_enqueued_jobs only: BackupProjectJob do
        BackupAllProjectsJob.perform_now
      end
    end
  end
end
