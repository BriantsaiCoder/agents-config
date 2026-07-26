# React Golden Rules — Expanded

The Why behind each rule + code examples.

## 1. Function components + hooks only

No class components for new code.

**Why**: Hooks compose better, simpler to test. Class components are effectively legacy.

## 2. `useEffect` deps complete + correct

Include every reactive value referenced inside.

```tsx
// ❌ Missing dep
useEffect(() => { fetchUser(userId); }, []);

// ✅ Complete deps
useEffect(() => { fetchUser(userId); }, [userId]);
```

**Why**: Missing deps → stale closures. Effect reads old values; produces wrong behavior silently.

## 3. Don't create new references inside render

```tsx
// ❌ New object every render
<Chart options={{ color: 'red' }} />

// ✅ Stable reference
const chartOptions = useMemo(() => ({ color: 'red' }), []);
<Chart options={chartOptions} />
```

**Why**: New references defeat `React.memo` and cause unnecessary child re-renders.

## 4. Custom hooks for shared logic, `use` prefix

**Why**: Hooks encapsulate stateful logic — testable, reusable, no render props / HOCs.

## 5. State at the lowest needed level

Place state in the closest common ancestor that needs it.

**Why**: Lifting too high → unnecessary re-renders across the entire subtree.

## 6. Evaluate React Compiler first; without it, `React.memo` / `useMemo` / `useCallback` need a measured reason

**Why**: On React 19 with React Compiler enabled, memoization is automatic — manual memo is mostly redundant and should be deleted (`eslint-plugin-react-hooks` → `preserve-manual-memoization` flags it). Without the compiler, premature memoization = complexity + memory cost; only when profiling shows it matters.

## 7. Stable unique key, never array index for dynamic lists

**Why**: Wrong keys associate state with wrong items → subtle UI corruption on reorder/filter/insert.

## 8. RSC by default; `"use client"` only for hooks / interactivity / browser APIs

**Why**: RSC reduces bundle size, enables direct data access, eliminates client-server waterfalls.

## 9. No runtime CSS-in-JS

No styled-components / Emotion in new projects. Tailwind or CSS Modules.

**Why**: Runtime CSS-in-JS incompatible with RSC + adds JS bundle cost for something CSS handles natively.

## 10. shadcn/ui as default UI primitive

Copy components into the repo; customize with Tailwind + Radix.

**Why**: Owned code > black-box dependency — readable, modifiable, debuggable. 2026 industry standard.

## 11. TanStack Query for server state, separate from client state

```tsx
// ✅ Server state
const { data, isLoading } = useQuery({
  queryKey: ['users', userId],
  queryFn: () => fetchUser(userId),
});

// ✅ Client state with Zustand
const theme = useThemeStore((s) => s.theme);
```

**Why**: Mixing them = stale data, manual cache invalidation, loading-state spaghetti.

## 12. ErrorBoundary for render errors

**Why**: Uncaught render error crashes the entire tree; ErrorBoundary contains blast radius.

## 13. Lazy loading + Suspense

`React.lazy()` + `<Suspense fallback>` for route-level code splitting.

**Why**: Smaller initial bundle = faster first paint.

## 14. TypeScript: `interface` for Props, no `any`

**Why**: Typed props are self-documenting + catch breaking changes at compile time.

## 15. `eslint-plugin-jsx-a11y` enabled

Recommended config on, in the same lint run as everything else.

**Why**: A11y defects in JSX are invisible in review and in the browser until someone tabs through. The plugin flags JSX-level offenders — interaction handlers on non-interactive elements, missing `alt`, inputs with no associated label — at lint time; Lighthouse / axe only catch them once the page is rendered. Rule semantics + WCAG detail → `css-ui-best-practices`.

## Working Pattern — Writing

1. Server Component or Client? Default to Server unless you need hooks / interactivity.
2. Define Props interface; include `children` only if needed.
3. Local `useState` first. Lift / externalize only when multiple components need it.
4. Server data → TanStack Query (or RSC direct fetch). Client state → `useState` / `useReducer` / Zustand.
5. UI primitives → check shadcn/ui first.
6. Style with Tailwind utility classes; `cn()` (clsx + tailwind-merge) for conditional classes.
7. ErrorBoundary around data-dependent renders. TanStack Query's `error` state for expected API failures.
8. Accessibility: semantic HTML (`<button>`, `<table>`, `<nav>`), `alt` on images, keyboard nav. Detailed A11y → `css-ui-best-practices` skill.
9. Write tests (see `references/testing-and-routing.md`).
10. Run in dev; check React DevTools Profiler for re-renders.
11. No Tailwind → CSS Modules; never runtime CSS-in-JS.

## Working Pattern — Reviewing

1. **Correctness** — stale closures (missing `useEffect` deps)? Direct DOM manipulation? `setState` after unmount?
2. **A11y** — `<button>` not `<div onClick>`? `alt` on images? Keyboard navigable? Detailed → `css-ui-best-practices`.
3. **Keys** — `key={index}` on dynamic lists? Missing keys?
4. **Performance** — inline objects / functions in JSX props of memoized children? Re-renders visible in Profiler? Missing code splitting on heavy routes?
5. **Patterns** — prop drilling > 2 levels? God components? Business logic mixed into UI?
6. **Styling** — runtime CSS-in-JS in new code? Inconsistent class naming?
7. **Server/Client boundary** — `"use client"` on components that don't need it? Client-side fetch when RSC could do it?

Group findings by severity (correctness → A11y → keys/performance → patterns → style).
