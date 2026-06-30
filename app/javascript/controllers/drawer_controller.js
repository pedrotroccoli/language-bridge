import { Controller } from "@hotwired/stimulus"

// Right-side slide-over for the key detail panel. The trigger links load their
// content into the "key_detail" turbo frame inside the panel; open() just
// reveals the panel (no preventDefault, so the frame still navigates).
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("hidden")
  }

  close(event) {
    event?.preventDefault()
    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }
}
