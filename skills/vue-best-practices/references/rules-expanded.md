# Vue 3 Golden Rules — Expanded

The Why behind each rule + code examples.

## 1. `<script setup>` + Composition API

Use the repository's existing component convention. Options-to-Composition migration requires matching scope; a local patch does not authorize it.

**Why**: Better TS inference, less boilerplate, better tree-shaking. Recommended by Vue core team.

## 2. `ref` default; `reactive` only for nested objects

```vue
<script setup lang="ts">
// ❌ Loses reactivity on destructure
const state = reactive({ count: 0 });
const { count } = state; // count is now a plain number

// ✅ Always reactive
const count = ref(0);
</script>
```

**Why**: `ref` works uniformly for primitives + objects; `reactive` loses reactivity on destructure / spread.

## 3. Props via `defineProps<T>()`

```vue
<script setup lang="ts">
interface Props {
  title: string;
  count?: number;
}
const props = defineProps<Props>();
</script>
```

**Why**: Compile-time check + autocomplete, no runtime overhead.

## 4. Emits via `defineEmits<T>()`

Explicitly declare events with typed payloads.

**Why**: Typed emits = documentation + compile-time typo catch. Undeclared emit = silent no-op.

## 5. `computed` over template-side complex expressions

**Why**: Computed cached + only re-evaluates on dependency change. Template expressions re-run every render.

## 6. Cleanup `watch` / `watchEffect` side effects

```vue
<script setup lang="ts">
watchEffect((onCleanup) => {
  const timer = setInterval(() => poll(), 5000);
  onCleanup(() => clearInterval(timer));
});
</script>
```

**Why**: Uncleared timers / subscriptions / listeners → memory leaks + stale behavior.

## 7. Pinia setup stores, single responsibility

`defineStore('id', () => { ... })`. One domain per store.

**Why**: Setup syntax = full Composition API power. God-store = untestable.

## 8. `v-for` + stable `:key`

Unique IDs, never array index.

**Why**: Vue uses keys for DOM patching. Wrong key = state bleeds between list items.

## 9. Don't combine `v-if` + `v-for` on same element

Wrap with `<template v-for>` + inner `v-if`, or filter via `computed`.

**Why**: In Vue 3, `v-if` evaluates before `v-for` on the same element → confusing behavior, errors when condition depends on the loop variable.

## 10. Composables for shared logic, `use` prefix

`useAuth`, `useFetch`, `useDebounce`.

**Why**: Vue's mixins replacement without namespace collision / implicit deps.

## 11. Provide/Inject with typed `InjectionKey`

```typescript
// keys.ts
export const ThemeKey: InjectionKey<Ref<'light' | 'dark'>> = Symbol('theme');

// parent
provide(ThemeKey, theme);

// child
const theme = inject(ThemeKey); // Ref<'light' | 'dark'> | undefined
```

**Why**: Prevents runtime `undefined`, gives full editor autocomplete.

## 12. Match the repository's UI stack

Do not introduce a second UI library or styling system for a local change. Identify the existing stack from dependencies and nearby components; host/repo rules own greenfield defaults.

When the existing stack is headless, preserve its ARIA/keyboard behavior while styling. Package name is `reka-ui`; projects still on the pre-rename `radix-vue` keep that name until migrated (`radix-vue` → `reka-ui`, `--radix-*` → `--reka-*`, `data-radix-*` → `data-reka-*`).

**Why**: mixing component systems duplicates tokens, interaction conventions, CSS reset assumptions, and bundle cost.

## 13. Reuse installed composables

Reuse an installed composable when it matches the need. If VueUse is absent, evaluate native/existing tools before adding it; never persist tokens or PII in its storage composables.

**Why**: Reusing suitable installed composables avoids duplicate logic and unnecessary dependencies.

## 14. `<style scoped>` default; CSS Modules only when stricter isolation needed

**Why**: Scoped styles prevent leakage with minimal setup. CSS Modules add class name indirection.

## Working Pattern — Writing

1. `.vue` SFC with `<script setup lang="ts">`.
2. `defineProps<T>()` + `defineEmits<T>()`.
3. `ref()` for state. Extract shared logic into composables.
4. Preserve existing state/data-layer ownership. Use installed Pinia/VueUse only for matching needs; expose appropriate async error/loading state without introducing a dependency for a local change.
5. Unique IDs from `crypto.randomUUID()` or counter — never array index.
6. Forms: `@submit.prevent`, `v-model`, clear inputs after success.
7. UI: reuse the installed component system and its tokens.
8. Style with `<style scoped>` or the repository's existing CSS Modules/utility convention.
9. `<template v-for>` + `:key` for lists; never `v-if` + `v-for` on same element.
10. Tests for composables + stores (`references/testing.md`).
11. Run in dev, check Vue DevTools for unnecessary re-renders + reactivity issues.

## Working Pattern — Reviewing

1. **Reactivity** — destructured `reactive`? Direct prop mutation? Missing `.value` in script? Forgetting `toRef`/`toRefs` when passing reactive object to composables?
2. **Template** — `v-if` + `v-for` on same element? Missing/index `:key`? Complex expression that should be `computed`?
3. **Performance** — `watch` that could be `computed`? Missing `shallowRef` for large non-reactive objects? Heavy components without `defineAsyncComponent`?
4. **Patterns** — Options API in new code? Bloated component (> 300 lines)? Logic belongs in composable?
5. **Styling** — unscoped styles leaking? A second styling system introduced without need?
6. **Pinia** — store doing too much? Actions with side effects not returning promises?

Group findings by severity (reactivity → template → performance → patterns → style).
