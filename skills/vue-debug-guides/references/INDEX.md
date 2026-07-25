# Vue Debug Symptom Index

Use this as a first-pass map. Verify with the actual component, warning text, and failing flow before editing.

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

If the symptom is still unclear, search current Vue/Nuxt documentation, then hand off to the companion skill that owns the area — `vue-best-practices` (component / reactivity patterns), `pinia` (store state), `nuxt` (SSR, Nitro, hydration), `vueuse-functions` (composables).
