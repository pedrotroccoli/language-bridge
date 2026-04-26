---
tags: [rails, 37signals, mobile, responsive, css]
---

# Mobile

> Responsive CSS, safe area insets, touch optimization.

See also: [[css]], [[accessibility]], [[hotwire]]

---

## Responsive Patterns
- Negative margins to reclaim padding on mobile
- Stacked-to-grid: `grid-template-columns: repeat(2, 50%)` at 640px+
- Sticky headers with z-index management for dialogs
- Icon + badge navigation on mobile
- Viewport-adaptive limits: `(min-height)` and `(max-height)`

## Mobile-First CSS
- `clamp()` for fluid typography: `font-size: clamp(var(--text-medium), 6vw, var(--text-xx-large))`
- Responsive custom properties at breakpoints
- Conditional borders on mobile for visual separation
- Hide empty rich text: `p:only-child:has(br:only-child) { display: none; }`

## Touch Optimization
- Circle buttons on mobile (icon-only, hide text)
- Full-width touch targets on expand
- Disable empty states: `pointer-events: none` + `opacity: 0.5`
- Min touch target: 44x44px (iOS) / 48x48px (Android)

## Safe Area Insets
```html
<meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no, viewport-fit=cover">
```
```css
#header { padding-top: calc(var(--block-space-half) + env(safe-area-inset-top)); }
.tray { inset-block: auto env(safe-area-inset-bottom); }
```
Critical: `viewport-fit=cover` required for safe-area to work.

## Checklist
- [ ] Viewport meta with `viewport-fit=cover`
- [ ] Safe area insets on header/footer
- [ ] `clamp()` for fluid typography
- [ ] Touch targets ≥ 44x44px
- [ ] Stacked layouts on mobile
- [ ] Dark mode backgrounds
- [ ] Logical properties for RTL support
- [ ] `dvw`/`dvh` dynamic viewport units
