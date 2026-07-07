# Pinia (in Vue context)

For full Pinia coverage — store definition, state/getters/actions, store composition, SSR hydration, HMR, testing, plugins, "use outside component" patterns, and the deep gotcha catalog (No active Pinia, setup-store return rules, `storeToRefs`, URL-vs-store decision) — invoke the standalone **`pinia`** skill.

This file used to duplicate that content; it now intentionally redirects to keep one source of truth. When working on a Vue 3 project that uses Pinia, expect both `vue-best-practices` and `pinia` to apply.

## Vue-Specific Notes Not in the Pinia Skill

- **Setup-store + `<script setup>`** is the default for new Vue 3 code (Golden Rule #7). Options-style `defineStore('id', { state, getters, actions })` only for migrating Vue 2 / Vuex codebases.
- **`storeToRefs(store)`** in component setup keeps reactivity when destructuring state/getters. Actions are bound and can be destructured directly.
- **Where to put state — component vs Pinia**: lift to Pinia only when state is *shared across non-parent/child components* OR needs to *survive route changes*. Local UI state (`isOpen`, `hover`) belongs in the component.

For everything else, read the standalone `pinia` skill.
