import { Controller } from "@hotwired/stimulus"

// Submits the form when an input changes. With a delay value it debounces
// (search-as-you-type); with no delay it submits immediately (autosave on
// blur/change). The form targets a Turbo Frame, so only that part swaps.
export default class extends Controller {
  static values = { delay: { type: Number, default: 0 } }

  submit() {
    if (this.delayValue > 0) {
      clearTimeout(this.timeout)
      this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
    } else {
      this.element.requestSubmit()
    }
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
