---
tags: [rails, 37signals, accessibility, aria, a11y]
---

# Accessibility

> ARIA patterns, keyboard navigation, screen reader support, focus management.

See also: [[stimulus]], [[mobile]], [[hotwire]]

---

## ARIA Patterns
1. `aria-hidden="true"` on decorative elements (icons, duplicate links)
2. `aria-label` for icon-only buttons
3. `role="group"` with `aria-label` for related content
4. Counts: `pluralize(count, "comment")` for screen readers
5. `aria-label` and `aria-description` on dialogs
6. `role="button"` for non-button interactive elements
7. Toggle `aria-expanded` dynamically

## Keyboard Navigation
- `event.preventDefault()` on custom shortcuts
- Reusable NavigableList controller (arrows, Enter)
- `checkVisibility()` for visible item detection
- Support reverse navigation (bottom-to-top trays)
- Reset selection when dialogs open

## Screen Readers
- `.visually-hidden` / `.for-screen-reader`:
```css
.visually-hidden {
  clip-path: inset(50%);
  position: absolute;
  width: 1px; height: 1px;
  overflow: hidden;
  white-space: nowrap;
}
```
- Prefer visually hidden text over `aria-label` for complex content
- Fix form labels: `form.field_id(:assignee_ids, user.id)`
- Every input needs a label
- Semantic HTML: `<h1>`, `<nav>`, `<article>`

## Focus Management
- `:focus-visible` not `:focus`
```css
:is(a, button, input):where(:focus-visible) {
  outline: var(--focus-ring-size) solid var(--focus-ring-color);
  outline-offset: var(--focus-ring-offset);
}
```
- Hide focus on checkbox wrappers, show on parent: `&:has(input:focus-visible)`
- `.hide-focus-ring` for rich text editors
- Focus first element when dialog opens
- `aria-selected` for custom list navigation

## Platform-Specific
- Adapt shortcuts: Cmd vs Ctrl
- `@media (any-hover: hover)` for hover effects
- Touch + mouse support

## Quick Wins Checklist
- [ ] `aria-hidden="true"` on decorative icons
- [ ] `.for-screen-reader` on icon-only buttons
- [ ] `aria-label` on dialogs
- [ ] `pluralize()` for screen reader counts
- [ ] `form.field_id()` for label associations
- [ ] `:focus-visible` instead of `:focus`
- [ ] `event.preventDefault()` on keyboard shortcuts
- [ ] Semantic HTML
- [ ] Keyboard-only navigation test
- [ ] Lighthouse accessibility audit
