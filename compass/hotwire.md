---
tags: [rails, 37signals, hotwire, turbo, morphing]
---

# Hotwire Patterns

> Turbo morphing, frames, state persistence, drag & drop.

See also: [[stimulus]], [[views]], [[actioncable]]

---

## Turbo Morphing
- Enable globally: `turbo_refreshes_with method: :morph, scroll: :preserve`
- Listen for `turbo:morph-element` to restore client-side state
- `data-turbo-permanent` for elements that shouldn't refresh
- `refresh: :morph` on frames with `src` to prevent removal during morphs

## Turbo Frames
- Wrap form sections in frames to prevent reset on partial updates
- Lazy-load: `loading: "lazy"`
- `data-turbo-frame="_parent"` to target parent without knowing ID

## State Persistence
- localStorage for UI preferences
- Restore on `turbo:morph-element` events
- `nextFrame()` helper to wait for morph completion

## Links Over JavaScript
- Filter chips as plain `<a>` tags — right-click, cmd+click work
- Better browser affordances, simpler code

## Cached Fragment Personalization
```javascript
class Current {
  get user() {
    return { id: parseInt(document.head.querySelector('meta[name="current-user-id"]')?.content) }
  }
}
window.Current = new Current()
```
```erb
<meta name="current-user-id" content="<%= Current.user&.id %>">
<div data-creator-id="<%= comment.creator_id %>" data-personalize-target="item">
```

## Progressive Installation
```javascript
connect() { this.element.classList.add("installed") }
```
```css
.widget { visibility: hidden; }
.widget.installed { visibility: visible; }
```

## Drag and Drop
- `await nextFrame()` before applying drag classes
- Track source container to prevent self-drop
- Optimistically remove on drop
- Let server handle ordering and re-render
- Use `@rails/request.js`: `window.fetch = Turbo.fetch`

## Testing Turbo Frames
```ruby
assert_turbo_frame "comments", loading: "lazy"
assert_turbo_frame @user, :profile, target: "_top"
assert_no_turbo_frame "admin-panel"
```

## Common Issues

| Problem | Solution |
|---------|----------|
| Timers not updating after morph | Bind to `turbo:morph-element` |
| Forms resetting on refresh | Wrap in turbo frames |
| Flickering on replace | Use `method: :morph` |
| localStorage state lost | Restore on `turbo:morph-element` |
