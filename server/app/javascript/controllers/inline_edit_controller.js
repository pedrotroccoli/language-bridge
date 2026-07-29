import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display", "form", "input"]

  edit(event) {
    if (event) event.preventDefault()
    this.displayTarget.hidden = true
    this.formTarget.hidden = false
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel(event) {
    if (event) event.preventDefault()
    this.formTarget.hidden = true
    this.displayTarget.hidden = false
  }

  keydown(event) {
    if (event.key === "Escape") this.cancel(event)
  }
}
