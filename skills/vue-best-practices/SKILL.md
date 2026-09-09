---
name: vue-best-practices
description: "Write, review, or diagnose Vue 3 components, reactivity, composables, and Pinia state/tests. Nuxt routing, Nitro, and server rendering use nuxt."
---

# Vue 3 Best Practices

For React, this skill does **not** apply — say so and stop.

> **Check the minor first.** Vue 3.5 flipped semantics three rules depend on — reactive `defineProps` destructure, `useTemplateRef`, `onWatcherCleanup`. Same code means different things on 3.4 vs 3.5: read `package.json`. Pinia has its own floor — see `references/pinia/core-stores.md`.

## Mode

1. **Writing** — apply the rules proactively; don't ask before `<script setup>`, Composition API, or strict typing.
2. **Reviewing** — walk them as a checklist: reactivity correctness → performance → patterns.
3. **Debugging** — a runtime symptom is evidence work: capture the warning text and open `references/debugging/INDEX.md` before editing.

## Golden Rules

Each rule's why, code, and patterns → `references/rules-expanded.md` §1–14.

1. **`<script setup>` + Composition API.** No Options API in new code.
2. **`ref` default; `reactive` only for complex nested.**
3. **`defineProps<T>()`** — 3.5+ destructures with native defaults; pre-3.5 destructure silently freezes the value.
4. **`defineEmits<T>()`** — an undeclared emit is a silent no-op.
5. **`computed` over complex template expressions.**
6. **Cleanup `watch` / `watchEffect`** — `onWatcherCleanup()` on 3.5+, `onCleanup` parameter before that.
7. **Pinia setup stores, single responsibility.**
8. **`v-for` + stable unique `:key`, never index.**
9. **Never `v-if` + `v-for` on same element** — `<template v-for>` + inner `v-if`, or filter via `computed`.
10. **Composables for shared logic, `use` prefix.**
11. **Provide/Inject with typed `InjectionKey`.**
12. **Match the repository's component and styling stack.** No new UI library for a local change.
13. **VueUse for composables.**
14. **`<style scoped>` default; CSS Modules for stricter isolation.**

## Two calls no reference can make for you

- **Where state lives.** Pinia only when shared across non-parent/child components **or** it must survive route changes; `isOpen`/`hover` stay local, server state stays out.
- **Whether to add VueUse.** Prefer it over hand-rolled cleanup, SSR guards, observers, debounce, or reactive storage — but **never persist tokens or PII** through its storage composables.

## Reference Map

Paths under `references/`; open one at a time.

- `component-patterns.md` — SFC, props/emits, slots, async, Teleport, `defineModel`
- `state-management.md` — `ref` vs `reactive`, `computed`, `watch`, provide/inject
- `pinia/` — stores, plugins, composing, SSR, HMR; `pinia/unit-test-vue-pinia-patterns.md` picks the test harness
- `vueuse/INDEX.md` — requirement→composable map plus SSR guardrails
- `debugging/INDEX.md` — symptom map, first checks, shortcuts that hide the bug
- `performance.md` — `v-memo`, `shallowRef`, KeepAlive, virtual scroll, Suspense
- `router.md` — Vue Router 4, typed routes, lazy, guards
- `testing.md` — Vitest + Vue Test Utils, slots/stubs, composables
- `styling-and-ui.md` — `scoped`, `:deep()`, CSS Modules

SSR, Nitro, file routing, server data fetching → `nuxt`. `references/vueuse/` derives from SerKo's VueUse skill — MIT, notice at `references/vueuse/LICENSE.md`.
