# React Golden Rules — Expanded

The Why behind each rule + code examples.

## 1. Existing component patterns

Use functions/hooks for new components when consistent with repository conventions. Preserve class contracts in local fixes; modernization requires matching scope.

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

**Why**: Hooks can encapsulate shared stateful logic. Existing render-prop/HOC contracts can remain; replace them only for an in-scope behavior or maintenance need.

## 5. State at the lowest needed level

Place state in the closest common ancestor that needs it.

**Why**: Lifting too high → unnecessary re-renders across the entire subtree.

## 6. Evaluate React Compiler first; without it, `React.memo` / `useMemo` / `useCallback` need a measured reason

Check installed compiler configuration, profiling, and identity-sensitive consumers before adding or removing manual memoization. Compiler availability alone does not authorize deletion; preserve behavior and validate the affected path.

## 7. Stable unique key, never array index for dynamic lists

**Why**: Wrong keys associate state with wrong items → subtle UI corruption on reorder/filter/insert.

## 8. Follow the selected framework server/client model

Use RSC only in a framework that supports it; ordinary React components do not become Server Components by default. Next routing/RSC contracts belong to `next-best-practices`.

## 9. Preserve the repository styling system

Do not introduce or migrate a styling dependency for a local React fix. Framework compatibility and an authorized migration determine when replacement is necessary.

## 10. Reuse existing UI primitives

Use the selected component system; when shadcn is installed, its integration skill owns component/token configuration.

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

## 14. TypeScript: typed Props with the repository convention

**Why**: Typed props are self-documenting + catch breaking changes at compile time.

## 15. `eslint-plugin-jsx-a11y` enabled

Recommended config on, in the same lint run as everything else.

**Why**: A11y defects in JSX are invisible in review and in the browser until someone tabs through. The plugin flags JSX-level offenders — interaction handlers on non-interactive elements, missing `alt`, inputs with no associated label — at lint time; Lighthouse / axe only catch them once the page is rendered. Rule semantics + WCAG detail → `css-ui-best-practices`.

## Working Pattern — Writing

1. Identify the framework's server/client model; apply RSC rules only where supported.
2. Define Props using the existing `type`/`interface` convention; include `children` only if needed.
3. Local `useState` first. Lift / externalize only when multiple components need it.
4. Keep server data and client state separate using the existing data layer/cache.
5. Reuse selected UI primitives.
6. Follow the existing styling/token convention.
7. ErrorBoundary around data-dependent renders. TanStack Query's `error` state for expected API failures.
8. Accessibility: semantic HTML (`<button>`, `<table>`, `<nav>`), `alt` on images, keyboard nav. Detailed A11y → `css-ui-best-practices` skill.
9. Write tests (see `references/testing-and-routing.md`).
10. Run in dev; check React DevTools Profiler for re-renders.
11. Preserve styling dependencies unless a separately authorized migration is necessary.

## Working Pattern — Reviewing

1. **Correctness** — stale closures (missing `useEffect` deps)? Direct DOM manipulation? `setState` after unmount?
2. **A11y** — `<button>` not `<div onClick>`? `alt` on images? Keyboard navigable? Detailed → `css-ui-best-practices`.
3. **Keys** — `key={index}` on dynamic lists? Missing keys?
4. **Performance** — inline objects / functions in JSX props of memoized children? Re-renders visible in Profiler? Missing code splitting on heavy routes?
5. **Patterns** — prop drilling > 2 levels? God components? Business logic mixed into UI?
6. **Styling** — an unintended second styling system or broken existing tokens?
7. **Server/Client boundary** — in an RSC framework, verify framework contracts with their owner; do not impose RSC on ordinary React.

Group findings by severity (correctness → A11y → keys/performance → patterns → style).
