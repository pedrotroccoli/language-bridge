import { Controller } from "@hotwired/stimulus"

// Gates a destructive submit button behind a typed confirmation: the submit
// stays disabled until the input's value matches the required text (e.g. the
// project slug). Pair with the modal controller for the open/close behavior.
export default class extends Controller {
  static targets = ["input", "submit"]
  static values = { match: String }

  check() {
    this.submitTarget.disabled = this.inputTarget.value.trim() !== this.matchValue
  }

  // Reset when the dialog opens so a prior entry doesn't pre-enable the button.
  reset() {
    this.inputTarget.value = ""
    this.submitTarget.disabled = true
  }
}
