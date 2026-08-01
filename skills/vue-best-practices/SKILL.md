---
name: vue-best-practices
description: 'Use when writing or reviewing Vue 3 SFCs and component-level patterns — Composition API, script setup, ref/reactive, computed/watch, defineProps/emits, provide/inject, v-if/v-for, slots, async components, TypeScript with Vue; "add a Vue component", "is this reactive". Not: Pinia state→pinia, SSR→nuxt, browser composables→vueuse-functions, runtime debugging→vue-debug-guides.'
---

# Vue 3 Best Practices

For React, this skill does **not** apply — say so and stop.

> **Check the minor first.** Vue 3.5 flipped semantics three rules depend on — reactive `defineProps` destructure, `useTemplateRef`, `onWatcherCleanup`. Same code means different things on 3.4 vs 3.5: read `package.json`.

## Mode

1. **Writing** — apply Golden Rules proactively. Don't ask before using `<script setup>`, Composition API, or strict typing; just do it and briefly explain *why* if it differs.
2. **Reviewing** — walk the rules as a checklist. Prioritize reactivity correctness → performance → patterns.

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

## Companion Skills

- `vue-debug-guides` — runtime / hydration / async diagnose
- `pinia` — state deep dive
- `vueuse-functions` — composable catalog
- `nuxt` — SSR / file routing

## Reference Map

- `references/rules-expanded.md` — rule whys, code, patterns
- `references/component-patterns.md` — SFC, Props/Emits, Slots, async, Teleport, `defineModel`, reactive props destructure, `useTemplateRef`
- `references/state-management.md` — `ref` vs `reactive`, `computed`, `watch`, `onWatcherCleanup`, VueUse, provide/inject
- `references/performance.md` — `v-once`, `v-memo`, `shallowRef`, KeepAlive, virtual scroll, Suspense
- `references/router.md` — Vue Router 4, typed routes, lazy, guards, lifecycle
- `references/testing.md` — Vitest + Vue Test Utils, mount, slots/stubs, composables, `createTestingPinia`, Suspense, Teleport
- `references/styling-and-ui.md` — `scoped`, `:deep()`, `:slotted()`, `:global()`, CSS Modules, Naive UI / Tailwind + Headless
- `references/pinia.md` — `storeToRefs`, state placement

Open one at a time — don't preload.
