import { Controller } from "@hotwired/stimulus"

// Keeps the session dropdown's button label in sync with the selected radio.
// The button lives outside the table's Turbo Frame, so a frame refresh can't
// re-render it from the server — we reflect the choice here instead. Empty
// value ("All sessions") falls back to the default label; auto-submit handles
// refreshing the table frame.
export default class extends Controller {
  static targets = ["radio", "label"]

  connect() {
    this.update()
  }

  update() {
    const selected = this.radioTargets.find((radio) => radio.checked)
    const value = selected ? selected.value : ""
    this.labelTarget.textContent = value || "Sessions"
  }
}
