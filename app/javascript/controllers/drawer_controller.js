import { Controller } from "@hotwired/stimulus"

// Right-side slide-over for the key detail panel. The trigger links load their
// content into the "key_detail" turbo frame inside the panel; open() reveals it
// and takes over focus like a modal dialog (focus in, trap, restore on close).
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.previouslyFocused = document.activeElement
    this.panelTarget.classList.remove("translate-x-full")
    this.backdropTarget.classList.remove("hidden")
    this.panelTarget.setAttribute("aria-hidden", "false")
    requestAnimationFrame(() => this.focusFirst())
  }

  close(event) {
    event?.preventDefault()
    if (this.closed) return

    this.panelTarget.classList.add("translate-x-full")
    this.backdropTarget.classList.add("hidden")
    this.panelTarget.setAttribute("aria-hidden", "true")
    this.previouslyFocused?.focus()
  }

  // Keep Tab focus inside the open panel (the background isn't inert).
  trap(event) {
    if (this.closed || event.key !== "Tab") return

    const items = this.focusables()
    if (items.length === 0) return
    const first = items[0]
    const last = items[items.length - 1]

    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault()
      last.focus()
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault()
      first.focus()
    }
  }

  get closed() {
    return this.backdropTarget.classList.contains("hidden")
  }

  focusFirst() {
    const items = this.focusables()
    ;(items[0] || this.panelTarget).focus()
  }

  focusables() {
    return Array.from(
      this.panelTarget.querySelectorAll('a[href], button, textarea, input, select, [tabindex]:not([tabindex="-1"])')
    ).filter((el) => !el.disabled && el.offsetParent !== null)
  }
}
