import { Controller } from "@hotwired/stimulus"

// Shows a spinner + disables a submit button while its form is submitting,
// restoring it when the request finishes. Works with Turbo form submissions
// (turbo:submit-start / -end) and falls back to disabling on plain submit.
export default class extends Controller {
  static targets = ["spinner"]

  connect() {
    this.form = this.element.closest("form")
    if (!this.form) return
    this.onStart = () => this.start()
    this.onEnd = () => this.stop()
    this.form.addEventListener("turbo:submit-start", this.onStart)
    this.form.addEventListener("turbo:submit-end", this.onEnd)
    // Non-Turbo (full page) submit: disable so it can't be double-fired; the
    // navigation reloads the page, which naturally restores the button.
    this.form.addEventListener("submit", this.onStart)
  }

  disconnect() {
    if (!this.form) return
    this.form.removeEventListener("turbo:submit-start", this.onStart)
    this.form.removeEventListener("turbo:submit-end", this.onEnd)
    this.form.removeEventListener("submit", this.onStart)
  }

  start() {
    this.element.disabled = true
    this.element.setAttribute("aria-busy", "true")
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.remove("hidden")
  }

  stop() {
    this.element.disabled = false
    this.element.removeAttribute("aria-busy")
    if (this.hasSpinnerTarget) this.spinnerTarget.classList.add("hidden")
  }
}
