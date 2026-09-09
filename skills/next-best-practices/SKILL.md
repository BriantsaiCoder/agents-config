---
name: next-best-practices
description: "Write, review, or debug Next.js App Router behavior, including server/client boundaries, routing, data flow, and framework configuration."
---

# Next.js Best Practices

## Verification Gate

Check installed Next.js version and existing App Router conventions before applying version-sensitive advice. After material changes, prefer project scripts (`lint`, `typecheck`, `test`, `build`); at minimum run narrowest build/typecheck or explain why not.

## Reference Map

- [project-init.md](references/project-init.md) — `create-next-app` flags, stack (shadcn + Zustand + TanStack Query + RHF + Zod), feature-based layout, TanStack provider, Zustand only-client-state, build gate, domain scaffolds
- [file-conventions.md](references/file-conventions.md) — structure, special files, route segments (dynamic / catch-all / groups), parallel + intercept, v16 middleware → proxy rename
- [rsc-boundaries.md](references/rsc-boundaries.md) — async client component (invalid), non-serializable props, Server Action exceptions
- [async-patterns.md](references/async-patterns.md) — Next 15+ async `params` / `searchParams` / `cookies()` / `headers()`, migration codemod
- [runtime-selection.md](references/runtime-selection.md) — default Node, when Edge
- [directives.md](references/directives.md) — `'use client'`, `'use server'`, `'use cache'`
- [functions.md](references/functions.md) — `useRouter`/`usePathname`/`useSearchParams`/`useParams`; `cookies`/`headers`/`draftMode`/`after`; `generateStaticParams`/`generateMetadata`
- [error-handling.md](references/error-handling.md) — `error.tsx` / `global-error.tsx` / `not-found.tsx`; `redirect` / `permanentRedirect` / `notFound`; `forbidden` / `unauthorized`; `unstable_rethrow`
- [data-patterns.md](references/data-patterns.md) — Server Components vs Actions vs Route Handlers; waterfall avoidance (`Promise.all`, Suspense, preload); client fetch
- [route-handlers.md](references/route-handlers.md) — `route.ts`, GET conflicts with `page.tsx`, no React DOM, Actions vs Handlers
- [metadata.md](references/metadata.md) — static / dynamic / `generateMetadata`, OG via `next/og`, file conventions
- [image.md](references/image.md) — `next/image` over `<img>`, remote config, `sizes`, blur placeholder, LCP priority
- [font.md](references/font.md) — `next/font`, Google / local, Tailwind, subsets
- [bundling.md](references/bundling.md) — server-incompatible pkgs, CSS imports, polyfills, ESM/CJS, analysis
- [scripts.md](references/scripts.md) — `next/script` vs native, inline `id`, loading strategy, GA via `@next/third-parties`
- [hydration-error.md](references/hydration-error.md) — browser APIs, dates, invalid HTML, overlay debug
- [suspense-boundaries.md](references/suspense-boundaries.md) — CSR bailout for `useSearchParams` / `usePathname`
- [parallel-routes.md](references/parallel-routes.md) — modal via `@slot` + `(.)` interceptor, `default.tsx`, `router.back()`
- [self-hosting.md](references/self-hosting.md) — `output: 'standalone'`, multi-instance ISR cache handler
- [debug-tricks.md](references/debug-tricks.md) — MCP endpoint, `--debug-build-paths`

