import { Controller } from "@hotwired/stimulus"

// Progressive enhancement for the (server-rendered) storage-connection form:
// shows the fields/labels that apply to the selected service, toggles the
// credential block + secret visibility, and gates Save behind a successful
// "Test connection". The form itself is a plain Rails form_with — create vs
// update routing, method and CSRF are handled by Rails, not here.
export default class extends Controller {
  static targets = [
    "cloudFields", "regionField", "endpointField", "credFields", "inherit",
    "bucket", "bucketLabel", "keyLabel", "secretLabel", "secret", "secretIcon",
    "testResult", "submit"
  ]
  static values = { testUrl: String }

  connect() {
    this.applyService() // reflect the initially-checked service radio
  }

  // --- service-specific fields (driven by data-* on the checked radio) ---
  serviceChanged() {
    this.applyService()
    this.invalidate()
  }

  applyService() {
    const radio = this.element.querySelector('input[name="storage_connection[service]"]:checked')
    if (!radio) return
    const d = radio.dataset
    const cloud = d.cloud === "true"

    this.cloudFieldsTarget.hidden = !cloud
    if (!cloud) return

    this.regionFieldTarget.hidden = d.region !== "true"
    this.endpointFieldTarget.hidden = d.endpoint !== "true"
    this.bucketLabelTarget.textContent = d.bucketLabel
    this.keyLabelTarget.textContent = d.keyLabel
    this.secretLabelTarget.textContent = d.secretLabel
    if (this.hasBucketTarget) this.bucketTarget.placeholder = d.bucketPlaceholder || ""
    this.toggleInherit()
  }

  toggleInherit() {
    this.credFieldsTarget.hidden = this.inheritTarget.checked
    this.invalidate()
  }

  toggleSecret() {
    const showing = this.secretTarget.type === "text"
    this.secretTarget.type = showing ? "password" : "text"
    this.secretIconTarget.textContent = showing ? "visibility" : "visibility_off"
  }

  // --- Save gating: enabled only after a connection test succeeds ---
  invalidate() {
    this.testResultTarget.textContent = ""
    this.submitTarget.disabled = true
  }

  async test(event) {
    event.preventDefault()
    this.renderTest("Testing connection…", "text-mut")
    try {
      // Strip Rails' method-override field: on the edit form it carries
      // _method=patch, which would reroute this POST to #update (id="test").
      const body = new FormData(this.element.querySelector("form"))
      body.delete("_method")
      const res = await fetch(this.testUrlValue, {
        method: "POST",
        headers: { "X-CSRF-Token": this.csrfToken, Accept: "application/json" },
        body
      })
      const json = await res.json()
      this.renderTest(json.message, json.ok ? "text-ok-ink" : "text-danger-ink")
      this.submitTarget.disabled = !json.ok
    } catch (e) {
      this.renderTest(`Test failed: ${e.message}`, "text-danger-ink")
      this.submitTarget.disabled = true
    }
  }

  renderTest(message, klass) {
    this.testResultTarget.className = `text-[12.5px] ${klass}`
    this.testResultTarget.textContent = message
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
