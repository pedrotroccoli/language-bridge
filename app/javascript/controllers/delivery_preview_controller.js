import { Controller } from "@hotwired/stimulus"

// Live preview of the delivery path template. As the operator edits the
// template, render the resulting object keys for a few sample (namespace,
// locale) pairs supplied via the `samples` value.
export default class extends Controller {
  static targets = ["input", "output"]
  static values = { samples: Array }

  connect() {
    this.render()
  }

  render() {
    const template = this.inputTarget.value
    this.outputTarget.innerHTML = ""

    for (const s of this.samplesValue) {
      const key = template
        .replaceAll("{project_slug}", s.project_slug)
        .replaceAll("{namespace}", s.namespace)
        .replaceAll("{locale}", s.locale)

      const row = document.createElement("div")
      row.className = "font-mono text-[12px] text-ink-3 truncate"
      row.textContent = key
      this.outputTarget.appendChild(row)
    }
  }
}
