# Nuxt — Anti-Patterns, SSR Bugs, Review Checklist

## Anti-Patterns

- **Browser API at module scope** (e.g., `const ws = new WebSocket(...)` in a composable's top level). Crashes during SSR. Wrap with `if (import.meta.client)` or use `onMounted`.
- **Module-scope mutable state** (e.g., `let cache = {}` in `composables/useThing.ts`). On the server it's shared across all requests — info leaks between users.
- **Reading `process.env.X` in client code.** Won't be defined in the browser bundle. Use `useRuntimeConfig().public.x`.
- **`useFetch` inside `onMounted`.** Loses SSR + skips dedup. Use `$fetch` for client-only flows.
- **Forgetting `transform` / `pick` on `useAsyncData`.** Massive payloads hydrate to the client unnecessarily — use `pick` to slim what crosses the wire.
- **Throwing raw errors in server routes.** Use `createError({ statusCode, statusMessage, data })` so `error.vue` and the client get structured info.
- **Catching hydration mismatch warnings instead of fixing them.** Mismatches are almost always "rendered different content server vs client" — usually `Date.now()`, `Math.random`, locale, or browser-only logic. Fix the source, don't suppress.

## SSR / Hydration Common Bugs

- **"Hydration mismatch"** → check for: client-only branches not guarded, formatted dates without explicit timezone, third-party UI libs that don't SSR (wrap in `<ClientOnly>`).
- **"Cannot use X from Vue outside setup function"** → composable used in async middleware after an `await` boundary; restore Nuxt context with `useNuxtApp()` or move work before `await`.
- **"Window is not defined"** → SSR path executing browser code; guard with `import.meta.client`.

## Review Checklist

- Browser-only APIs guarded with `import.meta.client` or `<ClientOnly>`.
- Runtime secrets in private `runtimeConfig`, never `runtimeConfig.public`.
- `useFetch` / `useAsyncData` at top level, with explicit keys for the latter.
- No module-scope mutable state in composables / server routes.
- Server routes validate input and return `createError(...)` for failures.
- Middleware and route rules align with deployment target (Vercel / Cloudflare / Node / static).
- Components / composables follow Nuxt auto-import conventions — no manual imports for things in `composables/` or `components/`.
