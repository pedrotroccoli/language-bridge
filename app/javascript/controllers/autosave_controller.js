import { Controller } from "@hotwired/stimulus"

// Submits the form when an input changes (e.g. on blur), so translation
// values save without an explicit button. The form is a Turbo Frame, so
// only its own cell is swapped on the response.
export default class extends Controller {
  save() {
    this.element.requestSubmit()
  }
}
