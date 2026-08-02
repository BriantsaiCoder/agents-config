---
name: vue-best-practices
description: 'Use for Vue 3 component, state, composable, and runtime-debugging work — Composition API, script setup, ref/reactive, computed/watch, defineProps/emits, provide/inject, slots, Pinia stores and store testing, VueUse composables, reactivity not updating, hydration mismatch, watcher loops; "add a Vue component", "share state across components", "I need a debounce", "this isn''t reactive", "I get a hydration warning". SSR, Nitro, and file routing → nuxt.'
---

# Vue 3 Best Practices

For React, this skill does **not** apply — say so and stop.

> **Check the minor first.** Vue 3.5 flipped semantics three rules depend on — reactive `defineProps` destructure, `useTemplateRef`, `onWatcherCleanup`. Same code means different things on 3.4 vs 3.5: read `package.json`. Pinia has its own floor — see `references/pinia/core-stores.md`.

## Mode

1. **Writing** — apply the rules proactively. Don't ask before `<script setup>`, Composition API, or strict typing; do it, and explain only where it differs.
2. **Reviewing** — walk them as a checklist: reactivity correctness → performance → patterns.
3. **Debugging** — a runtime symptom is evidence work, not a rules problem. Capture the warning text and open `references/debugging/INDEX.md` before editing.

## Golden Rules

Why + code + patterns → `references/rules-expanded.md`.

1. **`<script setup>` + Composition API.** No Options API in new code. Better TS inference, less boilerplate, tree-shake.
2. **`ref` default; `reactive` only for complex nested.** `reactive` loses reactivity on destructure/spread.
3. **`defineProps<T>()`** — compile-time check, no runtime overhead. 3.5+: destructure with native defaults; pre-3.5 destructure silently freezes the value.
4. **`defineEmits<T>()`** — undeclared emit = silent no-op; typed catches typos.
5. **`computed` over complex template expressions.** Cached; template re-runs every render.
6. **Cleanup `watch` / `watchEffect`** — `onWatcherCleanup()` on 3.5+ (works inside helpers), `onCleanup` parameter before that. Leaks otherwise.
7. **Pinia setup stores, single responsibility.** God-stores untestable.
8. **`v-for` + stable unique `:key`, never index.** Wrong key = state bleeds.
9. **Never `v-if` + `v-for` on same element** — `<template v-for>` + inner `v-if` or filter via `computed`. Vue 3: `v-if` evaluates before `v-for`.
10. **Composables for shared logic, `use` prefix.** Mixin replacement, no collisions.
11. **Provide/Inject with typed `InjectionKey`** — prevents runtime undefined.
12. **Match the repository's component and styling stack.** Do not introduce another UI library for a local change; host/repo rules own stack defaults.
13. **VueUse for composables** — tested, tree-shakable, Vue core maintained.
14. **`<style scoped>` default; CSS Modules for stricter isolation.**

## Two calls no reference can make for you

- **Where state lives.** Pinia only when shared across non-parent/child components **or** it must survive route changes; `isOpen`/`hover` stay local, server state stays out.
- **Whether to add VueUse.** Prefer it over hand-rolled cleanup, SSR guards, observers, debounce, or reactive storage — but **never persist tokens or PII** through its storage composables.

## Reference Map

Paths under `references/`. Open one at a time — don't preload.

- `rules-expanded.md` — rule whys, code, patterns
- `component-patterns.md` — SFC, props/emits, slots, async, Teleport, `defineModel`
- `state-management.md` — `ref` vs `reactive`, `computed`, `watch`, provide/inject
- `pinia/` — stores, plugins, composing, SSR, HMR; `pinia/unit-test-vue-pinia-patterns.md` picks the test harness
- `vueuse/INDEX.md` — requirement→composable map plus SSR guardrails
- `debugging/INDEX.md` — symptom map, first checks, shortcuts that hide the bug
- `performance.md` — `v-memo`, `shallowRef`, KeepAlive, virtual scroll, Suspense
- `router.md` — Vue Router 4, typed routes, lazy, guards
- `testing.md` — Vitest + Vue Test Utils, slots/stubs, composables
- `styling-and-ui.md` — `scoped`, `:deep()`, CSS Modules

SSR, Nitro, file routing, and server data fetching belong to `nuxt`. `references/vueuse/` derives from the VueUse skill by SerKo — MIT, notice at `references/vueuse/LICENSE.md`.
