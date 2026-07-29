import { Controller } from "@hotwired/stimulus"

const ALLOWED = /[a-z0-9_\-\.]/

export default class extends Controller {
  prevent(event) {
    if (event.inputType !== "insertText") return
    if (!event.data) return
    for (const ch of event.data.toLowerCase()) {
      if (!ALLOWED.test(ch)) {
        event.preventDefault()
        return
      }
    }
  }

  sanitize(event) {
    const input = event.target
    const before = input.value
    const caret = input.selectionStart ?? before.length

    let cleaned = ""
    let newCaret = caret
    for (let i = 0; i < before.length; i++) {
      const char = before[i].toLowerCase()
      if (ALLOWED.test(char)) {
        cleaned += char
      } else if (i < caret) {
        newCaret--
      }
    }

    if (cleaned !== before) {
      input.value = cleaned
      input.setSelectionRange(newCaret, newCaret)
    }
  }
}
