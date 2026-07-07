# VueUse Reference Index

This skill no longer vendors per-function documentation. Use this index to choose the likely composable, then verify exact options and return shape from the installed package types or current VueUse documentation.

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
