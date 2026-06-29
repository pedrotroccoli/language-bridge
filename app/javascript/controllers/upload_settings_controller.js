import { Controller } from "@hotwired/stimulus"

// Project Uploads card: shows/hides the override fields, and reflects the bucket
// prefix of the selected storage connection in the upload-path field.
export default class extends Controller {
  static targets = ["override", "overrideFields", "inheritSummary", "connection", "bucketPrefix"]

  connect() {
    this.toggleOverride()
    this.syncBucket()
  }

  toggleOverride() {
    const on = this.overrideTarget.checked
    if (this.hasOverrideFieldsTarget) this.overrideFieldsTarget.hidden = !on
    if (this.hasInheritSummaryTarget) this.inheritSummaryTarget.hidden = on
  }

  syncBucket() {
    if (!this.hasConnectionTarget || !this.hasBucketPrefixTarget) return
    const opt = this.connectionTarget.selectedOptions[0]
    const bucket = opt?.dataset.bucket
    this.bucketPrefixTarget.textContent = bucket ? `${bucket}/` : ""
    this.bucketPrefixTarget.hidden = !bucket
  }
}
