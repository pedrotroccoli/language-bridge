import { Controller } from "@hotwired/stimulus"

// Debounced search-as-you-type. Submits the form (a GET targeting a Turbo
// Frame) ~300ms after the last keystroke, so only the results frame swaps and
// the input keeps focus.
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
