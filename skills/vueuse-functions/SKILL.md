---
name: vueuse-functions
description: Use when Vue 3 / Nuxt 3 work touches browser APIs, storage, sensors, reactive utilities, async state, events, observers, timing, media, networking, or any reusable composable that VueUse may already provide. Apply even when user says "I need a debounce", "watch element size", "click outside", or "reactive localStorage" without naming VueUse.
---

# VueUse Functions

Maintained Vue 3 composable library. Skill value = routing: proven composable avoids fragile cleanup, SSR guards, debounce bugs, observer lifecycle, reactive storage mistakes.

## When To Use VueUse vs Hand-Roll

**Use VueUse when**: maps to Requirement Map; `@vueuse/core` installed or adding acceptable; would otherwise hand-roll cleanup / storage sync / observers / debounce-throttle / watch cleanup / media queries / async refs.

**Hand-roll when**: tiny project-owned composable; repo policy avoids VueUse; trivial wrapper + no deep imports yet.

## Decision Workflow

1. Confirm Vue 3 / Nuxt 3 context; inspect `package.json` for `@vueuse/core` / `integrations` / `router` / `rxjs` / `nuxt`.
2. Map requirement to category table.
3. Check current VueUse docs / installed types for exact signature; skill doesn't vendor function refs.
4. Nuxt: verify SSR/client boundaries — browser-only need `import.meta.client` / `onMounted` / `<ClientOnly>`.
5. Never persist tokens / PII via `useStorage` / `useLocalStorage` / `useSessionStorage`.

## Requirement Map

| Requirement | Prefer |
|---|---|
| Persistent reactive state | `useStorage`, `useLocalStorage`, `useSessionStorage`, `useStorageAsync` |
| Shared / global / injection state | `createGlobalState`, `createSharedComposable`, `createInjectionState` |
| Async state / HTTP | `useAsyncState`, `useFetch`, `useAxios` |
| DOM size / visibility / position | `useElementSize`, `useElementVisibility`, `useElementBounding`, `useResizeObserver`, `useIntersectionObserver` |
| Events / cleanup / scope | `useEventListener`, `onClickOutside`, `onKeyStroke`, `tryOnScopeDispose` |
| Timers / debounce / throttle | `useTimeoutFn`, `useIntervalFn`, `useDebounceFn`, `useThrottleFn`, `refDebounced`, `refThrottled` |
| Responsive / media queries | `useBreakpoints`, `useMediaQuery`, `useWindowSize`, `usePreferredDark`, `usePreferredReducedMotion` |
| Network / realtime | `useWebSocket`, `useEventSource`, `useOnline`, `useNetwork` |
| Clipboard / files / media | `useClipboard`, `useFileDialog`, `useObjectUrl`, `useUserMedia`, `useMediaControls` |
| Browser state | `useTitle`, `useUrlSearchParams`, `useBrowserLocation`, `useDark`, `useColorMode` |
| Animation / frame loops | `useTransition`, `useRafFn` |

## Boundary With Other Vue Skills

- `vue-best-practices` decides whether VueUse is appropriate at a component/composable level.
- This skill decides which VueUse category to check and which SSR/dependency guardrails apply.
- For Pinia state design, use `pinia`.
- For Nuxt server data fetching, use `nuxt`; do not confuse Nuxt `useFetch` with VueUse `useFetch`.

## Review Checklist

- VueUse reduces complexity versus hand-rolled code.
- Browser-only functions are guarded for SSR/Nuxt.
- Return values keep reactivity when destructured.
- Cleanup is automatic or explicitly handled.
- Additional integration packages are not introduced without approval.
