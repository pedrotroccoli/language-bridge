import { Controller } from "@hotwired/stimulus"

// Keeps the "N/total" badge in sync as locale checkboxes are toggled.
// Submitting the form (to refresh the table frame) is handled by auto-submit.
export default class extends Controller {
  static targets = ["count", "checkbox"]
  static values = { total: Number }

  updateCount() {
    const checked = this.checkboxTargets.filter((c) => c.checked).length
    this.countTarget.textContent = `${checked === 0 ? this.totalValue : checked}/${this.totalValue}`
  }
}
