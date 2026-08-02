---
name: vue-debug-guides
description: 'Use when diagnosing or fixing Vue 3 and Nuxt 3/4 runtime bugs — reactivity not updating, hydration mismatch, async/await in setup, ref unwrapping, watcher loops, SSR-only crashes, memory leaks, errorCaptured/errorHandler. Apply even when user just says "this isn''t reactive", "page flashes on load", "I get a hydration warning", or "watch keeps firing" without naming Vue debugging specifically.'
---

# Vue Debug Guides
> **Archived 2026-08-02.** Its `references/INDEX.md` was relocated to
> `skills/vue-best-practices/references/debugging/INDEX.md` when this skill merged into `vue-best-practices`.
> The reference links below resolve there, not inside this archive.

Vue 3 and Nuxt 3/4 debugging for runtime issues, warnings, async failures, and hydration bugs. The symptom categories below are major-agnostic — Nuxt 4 changes directory layout, not these failure modes. For writing new Vue code and conventions, use `vue-best-practices`.

## How to Use

1. Reproduce the symptom or capture the exact warning/error text.
2. Match the symptom to the category map below.
3. Read `references/INDEX.md` for the likely root causes and first checks.
4. Fix the smallest verified cause, then rerun the failing flow or test.
5. Broaden only if the evidence does not match the first category.

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
| TypeScript / SFC / Plugins | defineProps limits, withDefaults factory, named exports, install order, type augmentation |

## Debugging Rules

- Do not patch around hydration mismatch with client-only rendering until you know which value differs server vs client.
- Do not force rerender with keys until you prove stale component identity is the cause.
- Do not add deep watchers by default; first check whether the watched source is correct.
- In Nuxt, always separate server-safe code from browser-only APIs.

## Reference

- Compact symptom map and first checks: `references/INDEX.md`
