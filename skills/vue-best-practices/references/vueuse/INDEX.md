# VueUse Reference Index

Use this index to choose the likely composable, then verify exact options and return shape from the installed package types or current VueUse documentation — no per-function docs are vendored here.

## Use VueUse, or hand-roll?

Reach for VueUse when the requirement maps to an entry below and the cost of doing it yourself is cleanup, SSR guards, observer lifecycle, debounce correctness, or reactive storage sync — the four places hand-rolled composables usually leak. Hand-roll only for a trivial project-owned wrapper, or when repo policy forbids the dependency.

Before using one: confirm Vue 3 / Nuxt 3+ and check `package.json` for `@vueuse/core` (and `integrations` / `router` / `rxjs` / `nuxt` if the entry needs them). In Nuxt, guard browser-only functions with `import.meta.client`, `onMounted`, or `<ClientOnly>`, and never confuse Nuxt's `useFetch` with VueUse's. **Never persist tokens or PII** via `useStorage` / `useLocalStorage` / `useSessionStorage`. Do not add an extra integration package without approval.

Review check: the composable actually reduces complexity, return values keep reactivity when destructured, and cleanup is automatic or explicit.

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

Verify the exact signature and return shape against the installed types — the table maps requirement to candidate, it does not vendor the API.

## High-Frequency Mapping

- Events and cleanup: `useEventListener`, `onClickOutside`, `onKeyStroke`, `tryOnScopeDispose`.
- Storage: `useStorage`, `useLocalStorage`, `useSessionStorage`.
- Timing: `useTimeoutFn`, `useIntervalFn`, `useDebounceFn`, `useThrottleFn`, `refDebounced`, `refThrottled`.
- DOM observers: `useElementSize`, `useElementVisibility`, `useResizeObserver`, `useIntersectionObserver`.
- Browser/reactive state: `useWindowSize`, `useMediaQuery`, `usePreferredDark`, `useColorMode`, `useTitle`, `useUrlSearchParams`.
- Async/network: `useAsyncState`, `useFetch`, `useWebSocket`, `useEventSource`, `useNetwork`.

## Guardrails

- Check SSR behavior before using browser APIs in Nuxt.
- Do not store secrets or PII in browser storage.
- Prefer project-installed packages; ask before adding VueUse solely for a tiny wrapper.
