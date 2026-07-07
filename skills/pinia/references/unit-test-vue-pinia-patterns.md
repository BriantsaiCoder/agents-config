# Pinia Testing Snippets (Cookbook-Aligned)

Use these patterns directly when writing tests with `@pinia/testing`. The main `SKILL.md` decision tree points here when a non-default variant is needed — `initialState`, real actions, plugins, getter overrides, or pure-store testing without component mounting.

## Pure store unit test (no component, no testing-pinia)

For state transitions, getters, and action behaviour in isolation. Fastest, most precise — preferred whenever the test doesn't need a component mounted.

```ts
import { setActivePinia, createPinia } from "pinia";
import { beforeEach, expect, it } from "vitest";
import { useCounterStore } from "@/stores/counter";

beforeEach(() => {
  setActivePinia(createPinia());
});

it("increments", () => {
  const counter = useCounterStore();
  counter.increment();
  expect(counter.n).toBe(1);
});
```

Use `createTestingPinia` only when the store under test depends on *other* stores you need to stub, or when the action's spy assertions are the point.

## Minimal `createTestingPinia` variants (no `createSpy`)

Both of these are valid when the test doesn't inspect generated spies:

```ts
// Just need state seeding for a component test
createTestingPinia({
  initialState: {
    counter: { n: 5 },
  },
});

// Just want default action stubbing (so real action bodies don't run)
createTestingPinia({ stubActions: true });
```

Only add `createSpy: vi.fn` when you intend to write `expect(store.action).toHaveBeenCalled(...)` assertions.

## Composable / store-focused test with `setActivePinia`

When testing a composable or store that depends on other stores, mount-free:

```ts
import { setActivePinia } from "pinia";
import { createTestingPinia } from "@pinia/testing";

beforeEach(() => {
  setActivePinia(createTestingPinia({
    createSpy: vi.fn,
    initialState: {
      session: { user: { id: "u1" } },
    },
  }));
});
```

---

## Component mount with `createTestingPinia`

```ts
import { mount } from "@vue/test-utils";
import { createTestingPinia } from "@pinia/testing";
import { vi } from "vitest";

const wrapper = mount(ComponentUnderTest, {
  global: {
    plugins: [
      createTestingPinia({
        createSpy: vi.fn,
      }),
    ],
  },
});
```

## Execute real actions

Use this only when behavior inside the action must run.
If the test only checks call/no-call expectations, keep default stubbing (`stubActions: true`).

```ts
const wrapper = mount(ComponentUnderTest, {
  global: {
    plugins: [
      createTestingPinia({
        createSpy: vi.fn,
        stubActions: false,
      }),
    ],
  },
});
```

## Seed starting state

```ts
const wrapper = mount(ComponentUnderTest, {
  global: {
    plugins: [
      createTestingPinia({
        createSpy: vi.fn,
        initialState: {
          counter: { n: 10 },
          profile: { name: "Sherlock Holmes" },
        },
      }),
    ],
  },
});
```

## Use store in test and assert action call

```ts
const pinia = createTestingPinia({ createSpy: vi.fn });
const store = useCounterStore(pinia);

store.increment();
expect(store.increment).toHaveBeenCalledTimes(1);
```

## Add plugin under test

```ts
const wrapper = mount(ComponentUnderTest, {
  global: {
    plugins: [
      createTestingPinia({
        createSpy: vi.fn,
        plugins: [myPiniaPlugin],
      }),
    ],
  },
});
```

## Override and reset getters for edge tests

```ts
const pinia = createTestingPinia({ createSpy: vi.fn });
const store = useCounterStore(pinia);

store.double = 42;
expect(store.double).toBe(42);

// @ts-expect-error test-only reset
store.double = undefined;
```
