---
name: react-router-framework-mode
description: Use when building or reviewing React Router framework-mode apps — routes and nested layouts, route module exports, loaders/actions, redirects, Forms/fetchers, revalidation, navigation and link prefetching, pending or optimistic UI, error boundaries, sessions and protected routes, and SSR/SPA/prerender config in react-router.config.ts.
---

# React Router Framework Mode

Full-stack mode: file-based routing, SSR/CSR/static, data loading/mutations, type-safe route module API.

## When to Apply

Routes (`app/routes.ts`); `loader` / `clientLoader` data; `action` / `clientAction` mutations; `<Link>` / `<NavLink>` / `<Form>` / `redirect` / `useNavigate`; pending/loading UI; SSR / SPA / prerender (`react-router.config.ts`); auth.

## References

| File | Topic |
|---|---|
| `references/routing.md` | Routes, nested, dynamic segments |
| `references/route-modules.md` | All route module exports |
| `references/special-files.md` | root.tsx, global nav/footer, fonts |
| `references/data-loading.md` | Loaders, streaming, caching |
| `references/actions.md` | Forms, mutations, validation |
| `references/navigation.md` | Links, programmatic, redirects |
| `references/pending-ui.md` | Loading, optimistic UI |
| `references/error-handling.md` | Error boundaries |
| `references/rendering-strategies.md` | SSR / SPA / prerender |
| `references/middleware.md` | Middleware (v7.9.0+) |
| `references/sessions.md` | Cookie sessions, auth, protected routes |
| `references/type-safety.md` | Auto-generated route types |

## Version Compatibility

Verify with `npm list react-router` before implementing.

| Feature | Version | Notes |
|---|---|---|
| Middleware | 7.9.0–7.x | Requires `future.v8_middleware: true` |
| Middleware | 8.0+ | On by default — do **not** set `v8_middleware` |
| Core framework | 7.0.0+ | loaders, actions, Form |

On 8.x, delete every `future.v8_*` key from `react-router.config.ts`: those flags were removed once their behavior became the default, and leftovers fail config validation.

## Critical Patterns

These are the most important patterns to follow. Load the relevant reference for full details.

### Forms & Mutations

**Search forms** - use `<Form method="get">`, NOT `onSubmit` with `setSearchParams`:

```tsx
// ✅ Correct
<Form method="get">
  <input name="q" />
</Form>

// ❌ Wrong - don't manually handle search params
<form onSubmit={(e) => { e.preventDefault(); setSearchParams(...) }}>
```

**Inline mutations** - use `useFetcher`, NOT `<Form>` (which causes page navigation):

```tsx
const fetcher = useFetcher();
const optimistic = fetcher.formData?.get("favorite") === "true" ?? isFavorite;

<fetcher.Form method="post" action={`/favorites/${id}`}>
  <button>{optimistic ? "★" : "☆"}</button>
</fetcher.Form>;
```

See `references/actions.md` for complete patterns.

### Layouts

**Global UI belongs in `root.tsx`** - don't create separate layout files for nav/footer:

```tsx
// app/root.tsx - add navigation, footer, providers here
export default function App() {
  return (
    <div>
      <nav>...</nav>
      <Outlet />
      <footer>...</footer>
    </div>
  );
}
```

**Use nested routes** for section-specific layouts. See `references/routing.md`.

### Route Module Exports

**`meta` uses `loaderData`**, not deprecated `data`:

```tsx
// ✅ Correct
export function meta({ loaderData }: Route.MetaArgs) { ... }

// ❌ Wrong - `data` is deprecated
export function meta({ data }: Route.MetaArgs) { ... }
```

See `references/route-modules.md` for all exports.

## Further Documentation

If anything related to React Router is not covered in these references, you can search the official documentation:

https://reactrouter.com/docs
