---
tags: [rails, 37signals, stimulus, javascript]
---

# Stimulus Controllers

> 52 controllers, ~60/40 reusable/domain-specific. Single-purpose, configured via values/classes, event-based communication.

See also: [[hotwire]], [[accessibility]], [[views]]

---

## Reusable Controllers Catalog

### Copy-to-Clipboard (25 lines)
```javascript
export default class extends Controller {
  static values = { content: String }
  static classes = [ "success" ]
  async copy(event) {
    event.preventDefault()
    this.reset()
    try {
      await navigator.clipboard.writeText(this.contentValue)
      this.element.classList.add(this.successClass)
    } catch {}
  }
  reset() {
    this.element.classList.remove(this.successClass)
    this.element.offsetWidth // Force reflow
  }
}
```

### Auto-Submit (28 lines)
```javascript
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }
  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
  submitNow() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }
  disconnect() { clearTimeout(this.timeout) }
}
```

### Dialog (native `<dialog>`)
```javascript
export default class extends Controller {
  open() { this.element.showModal() }
  close() { this.element.close() }
  closeOnOutsideClick(event) {
    if (event.target === this.element) this.close()
  }
}
```

### Other Reusable Controllers
- **Auto-Click** (7 lines) — clicks element on connect
- **Element Removal** (7 lines) — removes element on action
- **Toggle Class** (31 lines) — toggle/add/remove CSS classes
- **Auto-Resize** (32 lines) — auto-expands textareas
- **Local Time** (40 lines) — user's local timezone
- **Beacon** (20 lines) — `navigator.sendBeacon` for tracking
- **Form Reset** (12 lines) — reset on successful submit
- **Character Counter** (25 lines) — remaining chars display

## Best Practices

### Use Values API
```javascript
static values = { url: String, delay: Number }
this.urlValue  // not this.element.getAttribute("data-url")
```

### Always Clean Up in `disconnect()`
```javascript
disconnect() {
  clearTimeout(this.timeout)
  this.observer?.disconnect()
  this.element.removeEventListener("custom", this.handler)
}
```

### Use `:self` Action Filter
```javascript
// Only trigger on this element, not bubbled events
data-action="click:self->modal#close"
```

### Dispatch Events for Communication
```javascript
this.dispatch("selected", { detail: { id: this.idValue } })
// data-action="dropdown:selected->form#updateField"
```

### Extract Shared Helpers
```javascript
// app/javascript/helpers/timing_helpers.js
export function debounce(fn, delay = 1000) {
  let timeoutId = null
  return (...args) => {
    clearTimeout(timeoutId)
    timeoutId = setTimeout(() => fn.apply(this, args), delay)
  }
}
```
