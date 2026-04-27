import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { openOnConnect: Boolean }

  connect() {
    if (this.openOnConnectValue) this.open()
  }

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
    const firstInput = this.dialogTarget.querySelector("input, textarea, select")
    firstInput?.focus()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
