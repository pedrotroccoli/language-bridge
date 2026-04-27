import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]
  static values = { openOnConnect: Boolean }

  connect() {
    if (this.openOnConnectValue && this.hasDialogTarget) this.open()
  }

  open(event) {
    event?.preventDefault()
    if (!this.hasDialogTarget || this.dialogTarget.open) return
    this.dialogTarget.showModal()
    const firstInput = this.dialogTarget.querySelector("input, textarea, select")
    firstInput?.focus()
  }

  close(event) {
    event?.preventDefault()
    if (this.hasDialogTarget && this.dialogTarget.open) this.dialogTarget.close()
  }

  closeOnBackdrop(event) {
    if (this.hasDialogTarget && event.target === this.dialogTarget) this.dialogTarget.close()
  }
}
