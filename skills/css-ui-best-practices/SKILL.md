---
name: css-ui-best-practices
description: "Write or review CSS, responsive layout, semantic HTML, and accessibility. Tailwind v4/shadcn token integration routes to tailwind-v4-shadcn."
---

# CSS / UI / Accessibility Best Practices

Portable CSS / UI / a11y rules. Apply proactively when writing and as a checklist when reviewing; host or repo rules own stack choices.

## CSS Defaults

- Match the repository's existing styling system; do not introduce a second one for a local change.
- Design tokens → CSS custom properties.
- Native CSS first: nesting, `@layer`, `:has()`, container queries.
- Resolve cascade conflicts using the existing layer/specificity model. Use a narrowly scoped `!important` only where that model requires an override; document the reason.

## Performance (Core Web Vitals)

- Prefer `transform` / `opacity`; when layout animation is required, verify frame responsiveness and reduced-motion behavior on the affected UI.
- Images: `aspect-ratio` (CLS-safe) + `loading="lazy"` (below fold) + `<picture>` WebP/AVIF.
- Do not add a UI framework for a few components; verify unused CSS from the production build.

## Accessibility — Non-Negotiable

Target WCAG 2.2 AA by default; verify the applicable legal standard for the product and jurisdiction. Full → `references/accessibility-responsive.md`.

- Semantic HTML before ARIA. `<button>` not `<div role="button">`.
- Keyboard-operable: Tab logical, Enter/Space activates, Escape closes overlays.
- Visible `focus-visible`. No `outline: none` without replacement.
- Modals: `<dialog>` or `role="dialog" aria-modal="true"` + focus trap + Escape + `aria-labelledby`.

## Writing Pattern

1. Semantic HTML first (`<header>`, `<nav>`, `<main>`, `<button>`).
2. Follow the repository's existing utility, module, or component pattern.
3. Keep design tokens in CSS custom properties or the existing theme layer.
4. Verify contrast in DevTools.
5. Keyboard: Tab / Enter / Space / Escape.
6. `alt` on images; `aria-label` only where semantic HTML insufficient.
7. Resize 320 → 1440 px; container queries for reusable.
8. Run the existing accessibility check when applicable; use keyboard/focus/label/contrast evidence for the changed UI. A tool score alone does not prove accessibility.

## Reviewing (severity)

1. **A11y** — missing alt, non-semantic interactive, contrast < AA, focus invisible, no keyboard support, modal without trap/Escape.
2. **Event** — overlay propagation bugs, inline `onclick` (CSP).
3. **Performance** — layout animation with demonstrated responsiveness or reduced-motion issues, missing below-fold `loading="lazy"`, unused CSS, unoptimized images.
4. **Responsive** — hardcoded px, no viewport meta, overflow on mobile, text too small.
5. **Maintainability** — `!important` outside a justified narrow override in the existing layer/specificity model, deep nesting, inline styles, inconsistent tokens.

## Reference Navigation

- `references/tailwind.md` — v4 setup, `@theme`, tokens, plugins, dark mode, shadcn/Headless UI
- `references/design-system-patterns.md` — token hierarchy, OKLCH token (shadcn), `cn()`, CVA, `size-*`, `@custom-variant`, compound, `tw-animate-css`, review
- `references/native-css-and-modules.md` — nesting, `@layer`, `:has()`, container, `@scope`, custom property, CSS Modules
- `references/accessibility-responsive.md` — WCAG 2.2 AA, ARIA, keyboard, responsive, Vitals
