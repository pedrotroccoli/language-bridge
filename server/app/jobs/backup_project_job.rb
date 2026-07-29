require "net/http"

# Snapshot one project's translations to the configured storage. The work lives
# on Project#create_backup!; the job just invokes it and retries transient
# storage/network failures (cloud uploads).
class BackupProjectJob < ApplicationJob
  queue_as :default

  retry_on Net::OpenTimeout, Net::ReadTimeout, wait: :polynomially_longer, attempts: 5

  def perform(project, source: "manual")
    project.create_backup!(source: source)
  end
end
