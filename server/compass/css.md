---
tags: [compass, css, design, native-css]
---

# CSS Architecture

> Native CSS with cascade layers, OKLCH colors, and modern features - no preprocessors.

See also: [[views]], [[stimulus]], [[accessibility]]

---

## Philosophy

Fizzy uses **native CSS only** - no Sass, PostCSS, or Tailwind. Modern CSS has everything needed:
- Native nesting
- CSS variables
- Cascade layers
- Container queries
- OKLCH color space

---

## Cascade Layers

```css
@layer reset, base, layout, components, utilities;

@layer reset {
  *, *::before, *::after {
    box-sizing: border-box;
  }
}

@layer base {
  body {
    font-family: system-ui, sans-serif;
    line-height: 1.5;
  }
}

@layer components {
  .card { }
  .btn { }
}

@layer utilities {
  .hidden { display: none; }
  .flex { display: flex; }
}
```

Later layers always win, regardless of selector specificity.

---

## OKLCH Color Space

```css
:root {
  --lch-blue-dark: 57.02% 0.1895 260.46;
  --lch-blue-medium: 66% 0.196 257.82;
  --lch-blue-light: 84.04% 0.0719 255.29;

  --color-link: oklch(var(--lch-blue-dark));
  --color-selected: oklch(var(--lch-blue-light));
}
```

Benefits:
- **Perceptually uniform** - Equal steps in lightness look equal
- **P3 gamut support** - Wider color range on modern displays
- **Easy theming** - Flip lightness values for dark mode

---

## Dark Mode via CSS Variables

```css
:root {
  --lch-ink-darkest: 26% 0.05 264;
  --lch-canvas: 100% 0 0;
}

html[data-theme="dark"] {
  --lch-ink-darkest: 96.02% 0.0034 260;
  --lch-canvas: 20% 0.0195 232.58;
}

@media (prefers-color-scheme: dark) {
  html:not([data-theme]) {
    --lch-ink-darkest: 96.02% 0.0034 260;
    --lch-canvas: 20% 0.0195 232.58;
  }
}
```

---

## Native CSS Nesting

```css
.btn {
  background-color: var(--btn-background);

  @media (any-hover: hover) {
    &:hover {
      filter: brightness(var(--btn-hover-brightness));
    }
  }

  html[data-theme="dark"] & {
    --btn-hover-brightness: 1.25;
  }

  &[disabled] {
    cursor: not-allowed;
    opacity: 0.3;
  }
}
```

---

## Component Naming Convention

BEM-inspired but pragmatic:

```css
.card { }
.card__header { }
.card__body { }
.card--notification { }
.card--closed { }
```

Heavy use of CSS variables for theming + `:has()` selectors for parent-aware styling.

---

## CSS Variables for Component APIs

```css
.btn {
  --btn-background: var(--color-canvas);
  --btn-border-color: var(--color-ink-light);
  --btn-color: var(--color-ink);
  --btn-padding: 0.5em 1.1em;
  --btn-border-radius: 99rem;

  background-color: var(--btn-background);
  border: 1px solid var(--btn-border-color);
  color: var(--btn-color);
  padding: var(--btn-padding);
  border-radius: var(--btn-border-radius);
}

.btn--link {
  --btn-background: var(--color-link);
  --btn-color: var(--color-ink-inverted);
}

.btn--negative {
  --btn-background: var(--color-negative);
  --btn-color: var(--color-ink-inverted);
}
```

---

## Modern CSS Features Used

### @starting-style for Entry Animations

```css
.dialog {
  opacity: 0;
  transform: scale(0.2);
  transition: 150ms allow-discrete;
  transition-property: display, opacity, overlay, transform;

  &[open] {
    opacity: 1;
    transform: scale(1);
  }

  @starting-style {
    &[open] {
      opacity: 0;
      transform: scale(0.2);
    }
  }
}
```

### color-mix() for Dynamic Colors

```css
.card {
  --card-bg-color: color-mix(in srgb, var(--card-color) 4%, var(--color-canvas));
  --card-text-color: color-mix(in srgb, var(--card-color) 75%, var(--color-ink));
}
```

### :has() for Parent-Aware Styling

```css
.btn:has(input:checked) {
  --btn-background: var(--color-ink);
  --btn-color: var(--color-ink-inverted);
}

.card:has(.card__closed) {
  --card-color: var(--color-card-complete) !important;
}
```

### Logical Properties

```css
.pad-block { padding-block: var(--block-space); }
.pad-inline { padding-inline: var(--inline-space); }
.margin-inline-start { margin-inline-start: var(--inline-space); }
```

### Container Queries

```css
.card__content {
  contain: inline-size;
}

@container (width < 300px) {
  .card__meta {
    flex-direction: column;
  }
}
```

### Field Sizing

```css
.input--textarea {
  @supports (field-sizing: content) {
    field-sizing: content;
    max-block-size: calc(3lh + (2 * var(--input-padding)));
  }
}
```

---

## Utility Classes (Minimal)

~60 focused utilities (unlike Tailwind's hundreds):

```css
@layer utilities {
  .txt-small { font-size: var(--text-small); }
  .txt-subtle { color: var(--color-ink-dark); }
  .txt-center { text-align: center; }

  .flex { display: flex; }
  .gap { column-gap: var(--column-gap, var(--inline-space)); }
  .stack { display: flex; flex-direction: column; }

  .pad { padding: var(--block-space) var(--inline-space); }

  .visually-hidden {
    clip-path: inset(50%);
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
  }
}
```

---

## Design Tokens

```css
:root {
  --inline-space: 1ch;
  --block-space: 1rem;
  --text-small: 0.85rem;
  --text-normal: 1rem;
  --text-large: 1.5rem;

  @media (max-width: 639px) {
    --text-small: 0.95rem;
    --text-normal: 1.1rem;
  }

  --z-popup: 10;
  --z-nav: 30;
  --z-tooltip: 50;
  --ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
  --dialog-duration: 150ms;
}
```

---

## Responsive Strategy

Minimal breakpoints, mostly fluid:

```css
--main-padding: clamp(var(--inline-space), 3vw, calc(var(--inline-space) * 3));
--tray-size: clamp(12rem, 25dvw, 24rem);

@media (max-width: 639px) { /* Mobile */ }
@media (min-width: 640px) { /* Desktop */ }
@media (max-width: 799px) { /* Tablet and below */ }
```

---

## File Organization

One file per concern, ~100-300 lines each:

```
app/assets/stylesheets/
├── _global.css          # CSS variables, layers, dark mode
├── reset.css
├── base.css
├── layout.css
├── utilities.css
├── buttons.css
├── cards.css
├── inputs.css
├── dialog.css
├── popup.css
└── application.css
```

---

## What's NOT Here

1. **No Sass/SCSS**
2. **No PostCSS**
3. **No Tailwind**
4. **No CSS-in-JS**
5. **No CSS Modules**
6. **No !important abuse** - Layers handle specificity

---

## Key Principles

1. **Use the platform** - Native CSS is capable
2. **Design tokens everywhere** - Variables for consistency
3. **Layers for specificity** - No specificity wars
4. **Components own their styles** - Self-contained
5. **Utilities are escape hatches** - Not the primary approach
6. **Progressive enhancement** - `@supports` for new features
7. **Minimal responsive** - Fluid over breakpoint-heavy
