import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "card", "empty", "query", "clearBtn"]

  connect() {
    this.filter()
  }

  filter() {
    const query = this.inputTarget.value.trim()
    const lowered = query.toLowerCase()
    let visible = 0

    this.cardTargets.forEach((card) => {
      const haystack = (card.dataset.searchableText || "").toLowerCase()
      const match = lowered === "" || haystack.includes(lowered)
      card.hidden = !match
      if (match) visible++
    })

    if (this.hasEmptyTarget) {
      this.emptyTarget.hidden = visible > 0 || query === ""
    }
    if (this.hasQueryTarget) {
      this.queryTarget.textContent = query
    }
    if (this.hasClearBtnTarget) {
      this.clearBtnTarget.hidden = query === ""
    }
  }

  clear() {
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this.filter()
  }
}
