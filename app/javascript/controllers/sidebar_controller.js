import { Controller } from "@hotwired/stimulus"

// Collapsible editor workspace sidebar. Persists the state in localStorage.
export default class extends Controller {
  static targets = ["panel", "expand"]
  static values = { collapsed: Boolean }

  connect() {
    const saved = localStorage.getItem("lb:editorSidebar")
    if (saved !== null) this.collapsedValue = saved === "1"
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
  }

  collapsedValueChanged() {
    this.panelTarget.classList.toggle("hidden", this.collapsedValue)
    if (this.hasExpandTarget) this.expandTarget.classList.toggle("hidden", !this.collapsedValue)
    this.element.classList.toggle("md:w-[236px]", !this.collapsedValue)
    this.element.classList.toggle("md:w-[48px]", this.collapsedValue)
    localStorage.setItem("lb:editorSidebar", this.collapsedValue ? "1" : "0")
  }
}
