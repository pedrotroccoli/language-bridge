# A project's cloud backups: scheduling (when one is due) and snapshotting its
# translations to the configured storage in the chosen format.
module Project::Backups
  extend ActiveSupport::Concern

  included do
    has_many :backups, class_name: "Project::Backup", dependent: :destroy
  end

  # How long between automatic snapshots, per backup_frequency.
  def backup_interval
    { "daily" => 1.day, "weekly" => 1.week, "monthly" => 1.month }.fetch(backup_frequency, 1.day)
  end

  # Is an automatic backup due? Enabled, the configured run-at hour (UTC) has
  # passed today, and none has been taken within the interval. BackupAllProjectsJob
  # runs hourly, so the time-of-day gate is what pins the run to backup_time_of_day.
  def backup_due?
    return false unless backups_enabled
    return false if Time.current.utc.hour < backup_time_of_day

    last = backups.maximum(:created_at)
    last.nil? || last <= backup_interval.ago
  end

  # Snapshot this project's translations to the configured storage and prune old
  # backups. Returns the Project::Backup (or nil if an auto backup was skipped
  # because nothing changed). Invoked by BackupProjectJob — kept here so the job
  # stays shallow and the behavior lives with the domain.
  def create_backup!(source: "manual")
    snapshot = TranslationSnapshot.build(self, include_drafts: backup_include_drafts)
    body, content_type, extension = Snapshot.dump(snapshot, format: backup_format)
    checksum = Digest::SHA256.hexdigest(body)
    return if source == "auto" && backups.recent.first&.checksum == checksum

    backup = backups.create!(source: source, format: backup_format, checksum: checksum,
                             translations_count: translations.count, byte_size: body.bytesize)
    backup.file.attach(**backup_attach_options(backup, body, content_type, extension))
    backups.recent.offset(backup_retention).destroy_all # retention
    backup
  end

  private
    def backup_attach_options(backup, body, content_type, extension)
      # Everything for a project lives under its own folder: <slug>/backups/...,
      # next to the delivery artifacts at <slug>/<namespace>/<locale>.json.
      rel = "#{slug}/backups/#{backup.created_at.utc.strftime('%Y%m%d-%H%M%S')}-#{backup.id}.#{extension}"
      options = { io: StringIO.new(body), key: storage_key(rel), filename: "#{slug}.#{extension}", content_type: content_type }
      if (service = storage_service_name)
        options[:service_name] = service
      end
      options
    end
end
