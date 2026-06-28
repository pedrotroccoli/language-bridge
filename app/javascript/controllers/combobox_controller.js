import { Controller } from "@hotwired/stimulus"

// Searchable select. Single mode writes the chosen value into a hidden field.
// Multiple mode adds chips, each emitting a hidden input named `name`.
// Typing an exact/valid code and pressing Enter also adds it. No library.
export default class extends Controller {
  static targets = ["input", "value", "list", "option", "empty", "chips"]
  static values = { pattern: String, multiple: Boolean, name: String }

  connect() {
    this.selected = new Set()
    this.onDocClick = (e) => { if (!this.element.contains(e.target)) this.close() }
    document.addEventListener("click", this.onDocClick)
  }

  disconnect() {
    document.removeEventListener("click", this.onDocClick)
  }

  open() {
    this.listTarget.classList.remove("hidden")
    this.position()
  }

  close() { this.listTarget.classList.add("hidden") }

  // Cap the list to the available space and flip upward when there's more room
  // above — so it's never clipped by the dialog or the viewport.
  position() {
    const box = this.inputTarget.getBoundingClientRect()
    const margin = 12
    const below = window.innerHeight - box.bottom - margin
    const above = box.top - margin
    const style = this.listTarget.style

    if (below < 200 && above > below) {
      style.top = "auto"
      style.bottom = "calc(100% + 6px)"
      style.maxHeight = `${Math.max(120, Math.min(300, above))}px`
    } else {
      style.bottom = "auto"
      style.top = "calc(100% + 6px)"
      style.maxHeight = `${Math.max(120, Math.min(300, below))}px`
    }
  }

  filter() {
    const typed = this.inputTarget.value.trim()
    const q = typed.toLowerCase()
    let visible = 0
    let exact = null

    this.optionTargets.forEach((o) => {
      const taken = this.selected.has(o.dataset.code)
      const match = !taken && o.dataset.label.toLowerCase().includes(q)
      o.hidden = !match
      if (match) visible++
      if (!taken && o.dataset.code.toLowerCase() === q) exact = o
    })

    if (!this.multipleValue) {
      let value = exact ? exact.dataset.code : ""
      if (!value && typed && this.patternValue) {
        try { if (new RegExp(this.patternValue).test(typed)) value = typed } catch (_) {}
      }
      this.valueTarget.value = value
    }

    if (this.hasEmptyTarget) this.emptyTarget.hidden = visible > 0
    this.open()
  }

  select(event) {
    const option = event.currentTarget
    if (this.multipleValue) {
      this.addChip(option.dataset.code, option.dataset.display || option.dataset.code)
      this.inputTarget.value = ""
      this.inputTarget.focus()
      this.filter()
    } else {
      this.valueTarget.value = option.dataset.code
      this.inputTarget.value = option.dataset.display
      this.close()
    }
  }

  // Enter adds the typed code (exact catalog match or a valid custom tag) in multi mode.
  enter(event) {
    if (!this.multipleValue) return
    const typed = this.inputTarget.value.trim()
    if (!typed) return
    event.preventDefault()

    const opt = this.optionTargets.find((o) => o.dataset.code.toLowerCase() === typed.toLowerCase())
    if (opt) {
      this.addChip(opt.dataset.code, opt.dataset.display || opt.dataset.code)
    } else if (this.patternValue && new RegExp(this.patternValue).test(typed)) {
      this.addChip(typed, typed)
    } else {
      return
    }
    this.inputTarget.value = ""
    this.filter()
  }

  addChip(code, label) {
    if (this.selected.has(code)) return
    this.selected.add(code)

    const chip = document.createElement("span")
    chip.dataset.code = code
    chip.className = "chip"
    chip.innerHTML = `<span>${label}</span>`

    const remove = document.createElement("button")
    remove.type = "button"
    remove.textContent = "×"
    remove.setAttribute("aria-label", `Remove ${label}`)
    remove.className = "chip__remove"
    remove.addEventListener("click", (e) => { e.stopPropagation(); this.removeChip(code) })
    chip.appendChild(remove)

    const hidden = document.createElement("input")
    hidden.type = "hidden"
    hidden.name = this.nameValue
    hidden.value = code
    chip.appendChild(hidden)

    this.chipsTarget.appendChild(chip)
  }

  removeChip(code) {
    this.selected.delete(code)
    this.chipsTarget.querySelector(`span[data-code="${code}"]`)?.remove()
    this.filter()
  }
}
