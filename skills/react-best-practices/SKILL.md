---
name: react-best-practices
description: 'Use when writing or reviewing React 18+/19 JSX/TSX: components, hooks, Context, Suspense, Server Components semantics, shadcn/ui, TanStack Query, keys, memoization, controlled inputs, DOM effects and cleanup, React-specific state patterns, excess re-renders, stale closures, and ref vs state.'
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
8. **RSC default; `"use client"` only for hooks / interactivity / browser APIs.**
9. **No runtime CSS-in-JS in new projects** — Tailwind or CSS Modules.
10. **shadcn/ui default UI primitive.** Owned code > black-box dep.
11. **TanStack Query for server state, separate from client.** Mixing → stale data, cache invalidation spaghetti.
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
