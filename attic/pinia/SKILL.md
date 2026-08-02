---
name: pinia
description: Use when working with Pinia stores in Vue 3 / Nuxt 3 or 4 — defining state/getters/actions, store composition, SSR hydration, HMR, testing, plugins, createTestingPinia, store unit tests, or "use outside component" patterns. Apply even when user just says "share state across components", "where do I put this global state", "mock this store", "stub this action", or "this state needs to persist" without naming Pinia.
---

<!-- last-verified: 2026-07-26 -->
# Pinia
> **Archived 2026-08-02.** Its `references/` payload was relocated to
> `skills/vue-best-practices/references/pinia/` when this skill merged into `vue-best-practices`.
> The reference links below resolve there, not inside this archive.

Pinia is the official Vue 3 state management library. This skill covers store design, SSR safety, plugins, and behavior-first testing.

> **Pinia 4:** ESM-only; install `@vue/devtools-api` separately. Its peers require
> Vue `^3.5.11` and TypeScript `>=5.6` when TypeScript is installed.
> Source: [Pinia v4 changelog](https://github.com/vuejs/pinia/blob/v4/packages/pinia/CHANGELOG.md).

## Workflow

1. Check whether the project already uses Pinia and which version is installed.
2. Prefer setup stores for new complex stores, especially when composables or watchers are needed.
3. Keep server state out of Pinia unless the project has explicitly chosen that pattern.
4. Use `storeToRefs()` when destructuring state or getters.
5. Add tests with `@pinia/testing`, pure `createPinia()`, or existing helpers when store behavior is non-trivial.

## Review Checklist

- Stores have focused domain responsibility and are not catch-all global state.
- State/getters/actions preserve reactivity when destructured.
- Stores used outside components are created inside functions or request-safe contexts, especially for SSR/Nuxt.
- Actions expose loading/error behavior when they perform async work.
- HMR support exists where the project uses it.
- Tests assert behavior through DOM, emitted events, callbacks, or store state rather than private component internals.

## Testing Decision Tree

1. Pure store logic: use `setActivePinia(createPinia())` and call store methods directly. Do not use `createTestingPinia`.
2. Component uses store and you assert an action was called: `createTestingPinia({ createSpy: vi.fn })`.
3. Component needs seeded state only: `createTestingPinia({ initialState: {...} })`.
4. Component must run real action side effects: `createTestingPinia({ createSpy: vi.fn, stubActions: false })`.
5. Prefer observable assertions. Use `wrapper.vm` only as a last resort and explain why.

## Core References

| Topic | Description | Reference |
|-------|-------------|-----------|
| Stores | Defining stores, state, getters, actions, storeToRefs, subscriptions | [core-stores](references/core-stores.md) |
| Plugins | Extend stores with custom properties, state, and behavior | [features-plugins](references/features-plugins.md) |
| Composables | Using Vue composables within stores | [features-composables](references/features-composables.md) |
| Composing Stores | Store-to-store communication, avoiding circular dependencies | [features-composing-stores](references/features-composing-stores.md) |
| Testing | `@pinia/testing`, pure store tests, action stubs, component patterns | [unit-test-vue-pinia-patterns](references/unit-test-vue-pinia-patterns.md) |
| Outside Components | Using stores in navigation guards, plugins, middlewares | [best-practices-outside-component](references/best-practices-outside-component.md) |
| SSR | Server-side rendering, state hydration, request safety | [advanced-ssr](references/advanced-ssr.md) |
| Nuxt | Nuxt integration, auto-imports, SSR best practices | [advanced-nuxt](references/advanced-nuxt.md) |
| HMR | Hot module replacement for development | [advanced-hmr](references/advanced-hmr.md) |
