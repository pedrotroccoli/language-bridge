import { Controller } from "@hotwired/stimulus"

// Drives the storage-connection modal: service segmented switch (shows the right
// fields + labels per service), inherit-credentials toggle, secret visibility,
// "Test connection" (posts unsaved params to /storage_connections/test), and
// populating the form when editing an existing connection.
export default class extends Controller {
  static targets = [
    "dialog", "form", "title", "service", "segment",
    "cloudFields", "inherit", "credFields", "endpointField",
    "regionField", "bucket", "region", "bucketLabel", "keyLabel", "secretLabel",
    "secret", "secretToggleIcon", "testResult", "submit"
  ]
  static values = { createUrl: String, testUrl: String }

  // Per-service field labels, placeholders, and which fields apply.
  LABELS = {
    local: { cloud: false },
    s3:    { cloud: true, endpoint: true,  region: true,  bucket: "Bucket",    bucket_ph: "my-bucket-prod", key: "Access key ID", key_ph: "AKIAIOSFODNN7EXAMPLE", secret: "Secret access key",    secret_ph: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY" },
    gcs:   { cloud: true, endpoint: false, region: false, bucket: "Bucket",    bucket_ph: "my-bucket",      key: "Project ID",    key_ph: "my-gcp-project",        secret: "Service account JSON", secret_ph: '{ "type": "service_account", … }' },
    azure: { cloud: true, endpoint: false, region: false, bucket: "Container", bucket_ph: "my-container",   key: "Account name",  key_ph: "mystorageaccount",      secret: "Access key",           secret_ph: "base64-account-key==" }
  }

  openNew(event) {
    event?.preventDefault()
    this.editing = false
    this.formTarget.reset()
    this.formTarget.action = this.createUrlValue
    this.setMethod("post")
    this.titleTarget.textContent = "New connection"
    this.setService("local")
    this.clearTest()
    this.disableSave()
    this.dialogTarget.showModal()
  }

  openEdit(event) {
    event.preventDefault()
    this.editing = true
    const d = event.currentTarget.dataset
    this.formTarget.reset()
    this.formTarget.action = d.url
    this.setMethod("patch")
    this.titleTarget.textContent = "Edit connection"
    this.field("name").value = d.name || ""
    this.field("bucket").value = d.bucket || ""
    this.field("region").value = d.region || ""
    this.field("endpoint").value = d.endpoint || ""
    this.field("prefix").value = d.prefix || ""
    this.field("inherit_credentials").checked = d.inherit === "true"
    this.field("access_key_id").value = d.accessKeyId || ""
    this.field("secret_access_key").value = "" // never round-trip the secret
    this.field("secret_access_key").placeholder = "•••••••• (leave blank to keep)"
    this.setService(d.service || "local")
    this.clearTest()
    this.disableSave()
    this.dialogTarget.showModal()
  }

  close(event) {
    event?.preventDefault()
    if (this.dialogTarget.open) this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  pickService(event) {
    this.setService(event.currentTarget.dataset.service)
    this.invalidate()
  }

  // A successful test is only valid for the params that were tested — any edit
  // (typing, switching service, toggling inherit) re-locks Save until re-tested.
  invalidate() {
    this.clearTest()
    this.disableSave()
  }

  setService(service) {
    this.serviceTarget.value = service
    const cfg = this.LABELS[service] || this.LABELS.local

    this.segmentTargets.forEach((el) => {
      const active = el.dataset.service === service
      el.classList.toggle("bg-surface", active)
      el.classList.toggle("text-ink", active)
      el.classList.toggle("font-semibold", active)
      el.classList.toggle("shadow-sm", active)
      el.classList.toggle("text-mut", !active)
    })

    this.cloudFieldsTarget.hidden = !cfg.cloud
    if (!cfg.cloud) return

    this.endpointFieldTarget.hidden = !cfg.endpoint
    this.regionFieldTarget.hidden = !cfg.region
    this.bucketLabelTarget.textContent = cfg.bucket
    this.keyLabelTarget.textContent = cfg.key
    this.secretLabelTarget.textContent = cfg.secret

    // Per-service example placeholders.
    if (this.hasBucketTarget) this.bucketTarget.placeholder = cfg.bucket_ph || ""
    this.field("access_key_id").placeholder = cfg.key_ph || ""
    if (!this.editing) this.secretTarget.placeholder = cfg.secret_ph || ""

    this.toggleInherit()
  }

  toggleInherit() {
    this.credFieldsTarget.hidden = this.field("inherit_credentials").checked
    this.invalidate()
  }

  toggleSecret() {
    const input = this.secretTarget
    input.type = input.type === "password" ? "text" : "password"
    this.secretToggleIconTarget.textContent = input.type === "password" ? "visibility" : "visibility_off"
  }

  async test(event) {
    event.preventDefault()
    this.renderTest("Testing connection…", "text-mut")
    const data = new FormData(this.formTarget)
    try {
      const res = await fetch(this.testUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": this.csrfToken(), Accept: "application/json" },
        body: data
      })
      const json = await res.json()
      this.renderTest(json.message, json.ok ? "text-ok-ink" : "text-danger-ink")
      json.ok ? this.enableSave() : this.disableSave()
    } catch (e) {
      this.renderTest("Test failed: " + e.message, "text-danger-ink")
      this.disableSave()
    }
  }

  enableSave() {
    this.submitTarget.disabled = false
  }

  disableSave() {
    this.submitTarget.disabled = true
  }

  // --- helpers ---
  field(name) {
    return this.formTarget.querySelector(`[name="storage_connection[${name}]"]`)
  }

  setMethod(method) {
    let input = this.formTarget.querySelector('input[name="_method"]')
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "_method"
      this.formTarget.prepend(input)
    }
    input.value = method
  }

  renderTest(message, klass) {
    this.testResultTarget.className = "text-[12.5px] " + klass
    this.testResultTarget.textContent = message
  }

  clearTest() {
    this.testResultTarget.textContent = ""
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
