---
name: react-best-practices
description: "Write, review, or diagnose React components, hooks, state, and rendering behavior; framework routing and build concerns use their stack skills."
---

# React Best Practices

For Vue, this skill does **not** apply — say so and stop.

## Mode

1. **Writing** — apply Golden Rules proactively. Don't ask before using function components or proper hook patterns; just do it and briefly explain *why* if it differs.
2. **Reviewing** — walk the rules as a checklist. Prioritize correctness (stale closures, missing keys) → performance → patterns → style.

## Golden Rules

Why + code + patterns → `references/rules-expanded.md`.

1. **Function components + hooks only.** Class components legacy.
2. **`useEffect` deps complete.** Missing deps = stale closures, silent wrong behavior.
3. **No new refs in render.** Defeats `React.memo`, causes child re-renders.
4. **Custom hooks for shared logic, `use` prefix.** Testable; no render props / HOCs.
5. **State at lowest needed level.** Lifting too high → subtree re-renders.
6. **Evaluate React Compiler first; without it, `memo` / `useMemo` / `useCallback` need measured reason.** Compiler on → manual memo mostly redundant, delete it; off → premature = complexity + memory cost.
7. **Stable unique `key`, never index for dynamic lists.** Wrong keys → state bleeds, UI corruption.
8. **Follow the selected framework’s server/client model.** In an RSC-capable framework, use `"use client"` for client boundaries; ordinary React applications do not gain server components from this rule.
9. **Use the repository's styling system.** New-project stack choices belong to the host/repo design workflow; do not introduce or replace a styling dependency for a local change.
10. **Reuse the existing UI primitives.** When shadcn/ui is selected, its integration skill owns token and component configuration.
11. **Keep server state separate from local UI state.** Reuse the existing framework/data cache; evaluate TanStack Query only when the selected stack needs that capability.
12. **ErrorBoundary for render errors.** Uncaught error crashes whole tree.
13. **Lazy + Suspense** for route splitting. Smaller initial bundle.
14. **TS: `interface` for Props, no `any`.** Self-doc; compile-time breaking-change catch.
15. **`eslint-plugin-jsx-a11y` enabled.** Flags `<div onClick>` / missing `alt` at lint time; Lighthouse / axe only after render.

## Companion Skills

- `testing-library-react-best-practices` — RTL queries, userEvent, async, forms, hooks
- `vitest` / `jest-best-practices` — runner config
- `next-best-practices` — App Router, RSC, Server Actions
- `react-router-framework-mode` — framework-mode loaders / actions
- `css-ui-best-practices` — CSS / a11y / responsive
- `tailwind-v4-shadcn` — token wiring, dark mode

## Reference Map

- `references/rules-expanded.md` — rule whys, code, patterns
- `references/component-patterns.md` — components, Props, hooks, ErrorBoundary, `forwardRef`, lazy
- `references/state-management.md` — `useState`/`useReducer`, Context, Zustand, Redux Toolkit, TanStack Query
- `references/performance.md` — memo, Profiler, splitting, RSC, concurrent, virtualization
- `references/testing-and-routing.md` — test seams, MSW, Router / Next.js boundaries
- `references/styling-and-ui.md` — Tailwind + React, shadcn, `cn()`, CSS Modules, CSS-in-JS migration

Open one at a time.
