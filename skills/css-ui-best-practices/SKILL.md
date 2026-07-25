---
name: css-ui-best-practices
description: 'Use when writing or reviewing CSS, UI, a11y — SCSS, CSS Modules, native nesting, container queries, @layer, :has(), responsive/flex/grid, semantic HTML, alt text, focus states, CLS spike, mobile overflow, z-index war, missing focus ring, contrast fail, animation jank, "fix this layout", "make it responsive", "broken on mobile", "tab skips button". Tailwind v4 + shadcn tokens → tailwind-v4-shadcn.'
---

# CSS / UI / Accessibility Best Practices

User-stance rules for 2026 CSS / a11y. Apply proactively writing; checklist when reviewing.

## Stack Defaults

- New → **Tailwind v4** (Oxide engine 5–100× faster, `@theme` CSS-first, no JS config, native layers). Existing → match.
- Avoid runtime CSS-in-JS in new (RSC-incompatible, bundle cost). Maintain existing styled-components / Emotion.
- Design tokens → CSS custom properties.
- Native CSS first: nesting, `@layer`, `:has()`, container queries.
- No `!important`. Manage cascade with `@layer`.

## Performance (Core Web Vitals)

- Animate only `transform` / `opacity`. Never `width` / `height` / `top` (layout, jank, hurts INP).
- Images: `aspect-ratio` (CLS-safe) + `loading="lazy"` (below fold) + `<picture>` WebP/AVIF.
- Tailwind purges unused; no UI framework for a few components.

## Accessibility — Non-Negotiable

WCAG 2.2 AA = legal floor (ADA / EAA / EN 301 549). Full → `references/accessibility-responsive.md`.

- Semantic HTML before ARIA. `<button>` not `<div role="button">`.
- Keyboard-operable: Tab logical, Enter/Space activates, Escape closes overlays.
- Visible `focus-visible`. No `outline: none` without replacement.
- Modals: `<dialog>` or `role="dialog" aria-modal="true"` + focus trap + Escape + `aria-labelledby`.

## Writing Pattern

1. Semantic HTML first (`<header>`, `<nav>`, `<main>`, `<button>`).
2. Tailwind utilities; `@apply` only for repeats.
3. Tokens as CSS custom properties / Tailwind theme.
4. Verify contrast in DevTools.
5. Keyboard: Tab / Enter / Space / Escape.
6. `alt` on images; `aria-label` only where semantic HTML insufficient.
7. Resize 320 → 1440 px; container queries for reusable.
8. Lighthouse a11y → 100.

## Reviewing (severity)

1. **A11y** — missing alt, non-semantic interactive, contrast < AA, focus invisible, no keyboard support, modal without trap/Escape.
2. **Event** — overlay propagation bugs, inline `onclick` (CSP).
3. **Performance** — layout-triggering anim, missing `loading="lazy"`, unused CSS, unoptimized images.
4. **Responsive** — hardcoded px, no viewport meta, overflow on mobile, text too small.
5. **Maintainability** — `!important`, deep nesting, inline styles, inconsistent tokens.

## Reference Navigation

- `references/tailwind.md` — v4 setup, `@theme`, tokens, plugins, dark mode, shadcn/Headless UI
- `references/design-system-patterns.md` — token hierarchy, HSL (shadcn), `cn()`, CVA, `size-*`, `@custom-variant`, compound, animate, review
- `references/native-css-and-modules.md` — nesting, `@layer`, `:has()`, container, `@scope`, custom property, CSS Modules
- `references/accessibility-responsive.md` — WCAG 2.2 AA, ARIA, keyboard, responsive, Vitals
