---
name: nuxt
description: "Write or review Nuxt 3/4 routing, Nitro, data fetching, configuration, and rendering modes. Vue component/reactivity work uses vue-best-practices."
---

# Nuxt

> Nuxt 3.x / 4.x — **check the major first**. Nuxt 4 defaults `srcDir` to `app/`: `pages/` `composables/` `layouts/` `middleware/` move under it, `server/` stays at root, `srcDir: '.'` reverts. Then `nuxt.config.ts`: `compatibilityDate` pins Nitro/Image presets; `future.compatibilityVersion: 5` = v5 defaults, not v4. Then verify Nitro version — SSR/hydration and `useFetch` defaults shifted across 3.7 / 3.10 / 3.12.

Top-3 bug sources: (1) where code runs (SSR / client / Nitro / build-time), (2) double-hydrate / cross-request state leak, (3) runtime config leaked to client.

## Workflow

1. Identify the relevant Nuxt config, app/server paths, and environment key definitions from safe examples or schemas. Access secret-bearing `.env*` only when authorized and keep values out of output.
2. Rendering: SSR / SSG (`nitro.prerender`) / SPA (`ssr: false`) / Hybrid (`routeRules`).
3. For any code — SSR / hydration / Nitro / build?
4. Data fetching → decision tree below.
5. State → `useState(key, init)` or Pinia. Module-scope `let x = ...` leaks across requests.
6. Use project scripts for affected type/build checks. Rendering or Nitro changes need a production-preview smoke because development mode can hide those failures; shared S4 owns broader verification.

## Data Fetching

| Need | Use | Runs |
|---|---|---|
| SSR + hydrate | `useFetch` / `useAsyncData('key', () => $fetch(...))` | Server first, client deduped |
| Event handler | `$fetch` | Client only |
| Server-only | `$fetch` in `server/api/*.ts` | Nitro |
| Lazy | `useFetch({ lazy: true })` / `useLazyAsyncData` | Server `null` first, client fills |
| Re-fetch on route | `useFetch({ watch: [() => route.params.id] })` | Both |

- `useFetch` / `useAsyncData` MUST be at `<script setup>` top level or composable top level. Inside `onMounted` defeats SSR — use `$fetch`.
- Always pass `key` to `useAsyncData` — collisions = stale hydration.
- Secrets go in `runtimeConfig.x` (server), never `runtimeConfig.public.x` (client bundle).
- Don't mix `useFetch` + manual `$fetch` for same data — double fetch.

## Server / Middleware / Route Rules

| Goal | Use | File |
|---|---|---|
| HTTP endpoint | `defineEventHandler` | `server/api/*.ts` |
| Per-request (Nitro) | `defineEventHandler` | `server/middleware/*.ts` |
| Per-navigation (Router) | `defineNuxtRouteMiddleware` | `middleware/*.ts` / `*.global.ts` |
| Cache / ISR / prerender / headers | `routeRules` | `nuxt.config.ts` |
| 404 / error | `error.vue` | root |

Order: `server/middleware` → `server/api`; route middleware after Nitro, before render.

## Pitfalls and Review

Anti-patterns, hydration bugs, full review checklist → `references/pitfalls-and-review.md`. Read before SSR-crossing changes.

## Reference Map

- `references/pitfalls-and-review.md` — review PR, hydration debug, server route final
- `references/core-directory-structure.md` — auto-import scope
- `references/core-config.md`, `references/core-cli.md` — `nuxt.config.ts`, `nuxt` CLI
- `references/core-routing.md` — file routes, dynamic params, layouts
- `references/core-data-fetching.md`, `references/best-practices-data-fetching.md` — fetch deep dive
- `references/features-server.md`, `references/core-deployment.md` — Nitro, deploy presets
- `references/best-practices-ssr.md`, `references/rendering-modes.md` — SSR/SSG/SPA/hybrid
- `references/core-modules.md`, `references/advanced-{layers,hooks,module-authoring}.md` — modules, layers, hooks
