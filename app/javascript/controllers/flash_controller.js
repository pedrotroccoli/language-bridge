import { Controller } from "@hotwired/stimulus"

// Self-dismissing toast. Slides in on connect, auto-hides after `delay`,
// pauses on hover, and removes itself after the leave transition.
// 37signals-style: no library, just Stimulus + CSS transitions.
export default class extends Controller {
  static values = { delay: { type: Number, default: 4500 } }

  connect() {
    requestAnimationFrame(() => this.element.classList.remove("opacity-0", "translate-y-1"))
    this.arm(this.delayValue)
  }

  arm(ms) {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.dismiss(), ms)
  }

  pause() {
    clearTimeout(this.timeout)
  }

  resume() {
    this.arm(1500)
  }

  dismiss() {
    clearTimeout(this.timeout)
    this.element.classList.add("opacity-0", "translate-y-1")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
