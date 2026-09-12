---
name: react-best-practices
description: "Write, review, or diagnose React components, hooks, state, and rendering behavior; framework routing and build concerns use their stack skills."
---

# React Best Practices

For Vue files, continue with `vue-best-practices`. In mixed repositories, apply each framework skill to its relevant files and continue the authorized task.

## Mode

1. **Writing** — preserve repo React patterns in authorized additions/fixes. Class/component-contract migrations need a separate necessary scope decision; review-only work produces findings.
2. **Reviewing** — walk the rules as a checklist. Prioritize correctness (stale closures, missing keys) → performance → patterns → style.

## Golden Rules

Why + code + patterns → `references/rules-expanded.md`.

1. **Use existing component patterns.** Prefer functions/hooks for new components when that matches the repo; do not migrate classes for a local fix.
2. **`useEffect` deps complete.** Missing deps = stale closures, silent wrong behavior.
3. **No new refs in render.** Defeats `React.memo`, causes child re-renders.
4. **Custom hooks use the `use` prefix.** Extract genuinely shared logic; preserve working render-prop/HOC contracts unless the requested change requires replacement.
5. **State at lowest needed level.** Lifting too high → subtree re-renders.
6. **Check compiler configuration and measured behavior before changing memoization.** Keep identity-sensitive contracts; add/remove `memo` / `useMemo` / `useCallback` only with evidence or requested modernization.
7. **Stable unique `key`, never index for dynamic lists.** Wrong keys → state bleeds, UI corruption.
8. **Follow the selected framework’s server/client model.** In an RSC-capable framework, use `"use client"` for client boundaries; ordinary React applications do not gain server components from this rule.
9. **Use the repository's styling system.** New-project stack choices belong to the host/repo design workflow; do not introduce or replace a styling dependency for a local change.
10. **Reuse the existing UI primitives.** When shadcn/ui is selected, its integration skill owns token and component configuration.
11. **Keep server state separate from local UI state.** Reuse the existing framework/data cache; evaluate TanStack Query only when the selected stack needs that capability.
12. **ErrorBoundary for render errors.** Uncaught error crashes whole tree.
13. **Lazy + Suspense** for route splitting. Smaller initial bundle.
14. **Type Props using the repo's `type` or `interface` convention.** Preserve public types; narrow unknown values instead of spreading `any`.
15. **`eslint-plugin-jsx-a11y` enabled.** Flags `<div onClick>` / missing `alt` at lint time; Lighthouse / axe only after render.

React correctness stays here. Explicit performance optimization uses the installed Vercel performance skill (for example `build-web-apps:react-best-practices`); Next routing/RSC belongs to `next-best-practices`.

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

Load only task-relevant references; batch independent reads and reuse unchanged content already in context.
