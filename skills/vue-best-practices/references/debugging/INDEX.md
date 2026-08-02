# Vue Debug Symptom Index

Use this as a first-pass map. Reproduce the symptom and capture the exact warning text first, match it below, then fix the smallest verified cause and rerun the failing flow. Broaden only when the evidence does not match the first category.

## Three shortcuts that hide the real bug

- Do not patch a hydration mismatch with client-only rendering until you know *which value* differs server vs client.
- Do not force a rerender with `:key` until you have proven stale component identity is the cause.
- Do not add a deep watcher by default; first check that the watched source is correct.
- In Nuxt, keep server-safe code separated from browser-only APIs rather than guarding at the call site after the fact.

## Category Map

| Category | Typical symptoms |
|---|---|
| Reactivity | ref/reactive not updating, destructuring lost reactivity, proxy identity, same-tick batching |
| Computed / Watchers | computed side effects, conditional deps, watcher loops, async cleanup, flush timing |
| Components / Props / Emits | undeclared events, double firing, component ref missing, multi-root attrs |
| Templates / Refs / Forms | v-if/v-for errors, null template refs, v-model edge cases, IME composition |
| Lifecycle / Composables | DOM access before mount, async setup context, hidden side effects, missing cleanup |
| Slots / Provide / Attrs | slot scope confusion, non-reactive provide/inject, fallthrough attrs overwriting |
| Nuxt / SSR / Suspense | hydration mismatch, cross-request pollution, browser API on server, async component error UI |
| Transitions / Teleport / KeepAlive | target missing, nested router double mount, transition hooks not completing |
| Error handling | `errorCaptured` not firing, `app.config.errorHandler` missing async rejections, errors swallowed by a boundary, Suspense fallback masking the throw |
| TypeScript / SFC / Plugins | defineProps limits, withDefaults factory, named exports, install order, type augmentation |

## First Checks By Symptom

- Reactivity not updating: check destructuring of `reactive`, missing `.value`, shallow refs, proxy identity, and same-tick batching.
- Computed wrong or unstable: check side effects, mutation inside computed, parameters, and conditional dependencies.
- Watcher loop or stale data: check watched source shape, cleanup for async effects, `flush` timing, and deep watcher necessity.
- Hydration mismatch: compare server/client data, dates/random IDs, browser APIs, invalid HTML, and cross-request state.
- Component ref is null: check `v-if`, mount timing, async component, and `defineExpose` before `await`.
- Emits fire twice or not at all: check `defineEmits`, native event name collisions, and listener fallthrough.
- Slots render unexpectedly: check parent-only slot scope, named default slot syntax, and slot forwarding.
- Provide/inject not reactive: provide refs/computed values, not plain snapshots; ensure synchronous setup.
- Transitions or Teleport fail: check target existence, done callback, nested duration, scoped styles, and SSR target availability.
- Nuxt server crash: locate browser-only APIs and gate with `import.meta.client`, `onMounted`, or `<ClientOnly>`.

## Escalation

If the symptom is still unclear, search current Vue/Nuxt documentation. Store state, composables, and component patterns all stay in this skill — see `../pinia/`, `../vueuse/INDEX.md`, and `../component-patterns.md`. Only SSR, Nitro, and file-routing symptoms hand off, to `nuxt`.
