---
name: react-router-framework-mode
description: "Build or review React Router framework-mode routing, loaders/actions, forms, sessions, and rendering configuration."
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

- **Forms and mutations:** use `<Form method="get">` for search and `useFetcher` for inline mutations without navigation. The complete examples already live in [actions](references/actions.md#choosing-the-right-pattern).
- **Layouts:** put global navigation, footer and providers in `root.tsx`; use nested routes for section layouts. Follow [routing](references/routing.md) and its linked root-file examples.
- **Route exports:** `meta` consumes `loaderData`, not the deprecated `data` parameter. Follow [route-modules](references/route-modules.md#meta).

## Further Documentation

If anything related to React Router is not covered in these references, you can search the official documentation:

https://reactrouter.com/docs
