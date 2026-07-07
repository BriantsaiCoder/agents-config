# Vue 3 Testing

Vue 3 的推薦組合：**Vitest + Vue Test Utils** (component / composable / store), **Playwright** (E2E)。Vitest 與 Vite 共用 config、原生支援 SFC + TS + ESM、無需 Jest transform。

> 關於 Vitest 本身（vitest.config、mocking、coverage、environments、projects、type testing）的細節，使用 `vitest` skill。本文件聚焦 Vue 元件 / composable / Pinia / Router / Suspense / Teleport / Nuxt 的測試模式與陷阱。

## 目錄

- [Vitest setup（Vue 專用）](#vitest-setup-vue-專用)
- [Vue Test Utils — mount vs shallowMount、slots、stubs](#vue-test-utils--mount-vs-shallowmount-slots-stubs)
- [測試 Composables](#測試-composables)
- [測試 Pinia Stores](#測試-pinia-stores)
- [Suspense / async setup / defineAsyncComponent](#suspense--async-setup--defineasynccomponent)
- [Teleport 內容測試](#teleport-內容測試)
- [Snapshot 誤區](#snapshot-誤區)
- [E2E：Playwright vs Cypress](#e2e-playwright-vs-cypress)
- [Nuxt 3 測試簡述](#nuxt-3-測試簡述)

---

## Vitest setup（Vue 專用）

```ts
// vitest.config.ts
import { defineConfig } from 'vitest/config'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'happy-dom',  // 元件測試預設；需 jsdom 才完整支援的 API 再切
    globals: true,
    setupFiles: ['./tests/setup.ts'],
    coverage: {
      provider: 'v8',
      include: ['src/**/*.{ts,vue}'],
      exclude: ['src/**/*.d.ts', 'src/**/*.test.ts'],
    },
  },
})
```

```ts
// tests/setup.ts
import { config } from '@vue/test-utils'

config.global.stubs = {
  RouterLink: true,
  RouterView: true,
}
```

| Environment | 用途 |
|---|---|
| `happy-dom` | 元件測試預設，~2× 快於 jsdom |
| `jsdom` | 需要 jsdom 才覆蓋的 API（canvas、特定 MutationObserver 邊角） |
| `@vitest/browser` (Playwright provider) | 需真實 layout / `getBoundingClientRect` / 真實 event 才用 |

---

## Vue Test Utils — mount vs shallowMount, slots, stubs

`mount` 完整渲染子元件；`shallowMount` 將子元件替換為 stub（單元測試常用）。

```ts
import { mount, shallowMount } from '@vue/test-utils'
import UserCard from '@/components/UserCard.vue'

describe('UserCard', () => {
  const defaultProps = { user: { id: 1, name: 'Alice', email: 'alice@test.com' } }

  it('渲染使用者名稱', () => {
    const wrapper = shallowMount(UserCard, { props: defaultProps })
    expect(wrapper.find('[data-testid="user-name"]').text()).toBe('Alice')
  })

  it('點擊觸發 select 並帶上 user payload', async () => {
    const wrapper = mount(UserCard, { props: defaultProps })
    await wrapper.find('button').trigger('click')
    expect(wrapper.emitted('select')).toHaveLength(1)
    expect(wrapper.emitted('select')![0]).toEqual([defaultProps.user])
  })

  it('測試 slot 內容', () => {
    const wrapper = mount(UserCard, {
      props: defaultProps,
      slots: {
        default: '<span class="badge">VIP</span>',
        actions: `<template #actions="{ user }"><button>編輯 {{ user.name }}</button></template>`,
      },
    })
    expect(wrapper.find('.badge').text()).toBe('VIP')
  })

  it('使用 stubs 隔離子元件', () => {
    const wrapper = mount(UserCard, {
      props: defaultProps,
      global: {
        stubs: {
          Avatar: { template: '<div class="stub-avatar" />' },
          Badge: true,
        },
      },
    })
    expect(wrapper.find('.stub-avatar').exists()).toBe(true)
  })
})
```

### 測試「行為」而非「實作」

```ts
// ❌ 綁內部實作
it('calls internal method', () => {
  const wrapper = mount(Counter)
  wrapper.vm.incrementCounter()  // 內部方法
  expect(wrapper.vm.count).toBe(1)  // 內部 state
})

// ✅ 測使用者行為
it('increments count when button clicked', async () => {
  const wrapper = mount(Counter)
  await wrapper.find('[data-test="increment"]').trigger('click')
  expect(wrapper.text()).toContain('Count: 1')
})
```

### Async：`flushPromises`

```ts
import { mount, flushPromises } from '@vue/test-utils'

it('shows data after fetch', async () => {
  const wrapper = mount(UserProfile, { props: { id: 1 } })
  await flushPromises()
  expect(wrapper.text()).toContain('John Doe')
})
```

---

## 測試 Composables

### 純邏輯 — 直接呼叫

```ts
// composables/useCounter.ts
import { ref, computed } from 'vue'
export function useCounter(initial = 0) {
  const count = ref(initial)
  const doubled = computed(() => count.value * 2)
  return { count, doubled, increment: () => count.value++, decrement: () => count.value-- }
}

// useCounter.test.ts
describe('useCounter', () => {
  it('初始值 + doubled', () => {
    const { count, doubled } = useCounter(5)
    expect(count.value).toBe(5)
    expect(doubled.value).toBe(10)
  })
})
```

### 需要元件 lifecycle / inject — wrapper helper

`useSomething()` 用了 `inject` / `onMounted` / `provide` 時，直接呼叫會報 `inject() can only be used inside setup`。

```ts
import { mount } from '@vue/test-utils'
import { defineComponent } from 'vue'

function withSetup<T>(composable: () => T): T {
  let result!: T
  const Comp = defineComponent({
    setup() { result = composable(); return () => null },
  })
  mount(Comp)
  return result
}

it('useCounter via wrapper', () => {
  const { count, increment } = withSetup(() => useCounter(0))
  increment()
  expect(count.value).toBe(1)
})
```

---

## 測試 Pinia Stores

### 基本 — `setActivePinia`

```ts
import { createPinia, setActivePinia } from 'pinia'
import { beforeEach } from 'vitest'

beforeEach(() => setActivePinia(createPinia()))

it('uses store', () => {
  const store = useCounterStore()
  store.increment()
  expect(store.count).toBe(1)
})
```

### 元件 + `createTestingPinia`

`@pinia/testing` 自動把 actions 換成 spy，可注入 `initialState`。

```ts
import { createTestingPinia } from '@pinia/testing'
import { vi } from 'vitest'

it('顯示購物車總金額', () => {
  const wrapper = mount(ShoppingCart, {
    global: {
      plugins: [createTestingPinia({
        initialState: {
          cart: { items: [{ id: 1, price: 100, quantity: 2 }, { id: 2, price: 200, quantity: 1 }] },
        },
      })],
    },
  })
  expect(wrapper.find('[data-testid="total"]').text()).toContain('400')
})

it('呼叫 removeItem action', async () => {
  const wrapper = mount(ShoppingCart, {
    global: { plugins: [createTestingPinia({ createSpy: vi.fn })] },
  })
  const store = useCartStore()
  await wrapper.find('[data-testid="remove-btn"]').trigger('click')
  expect(store.removeItem).toHaveBeenCalledOnce()
})
```

更多 store 模式 → 參考 `pinia` skill。

---

## Suspense / async setup / defineAsyncComponent

Vue Test Utils 不會自動解 Suspense；用 `<Suspense>` 包裝 + `flushPromises`。

```ts
import { mount, flushPromises } from '@vue/test-utils'
import { Suspense, defineAsyncComponent } from 'vue'

it('async setup component', async () => {
  const wrapper = mount({
    components: { AsyncComp, Suspense },
    template: '<Suspense><AsyncComp /></Suspense>',
  })
  await flushPromises()
  expect(wrapper.text()).toContain('John')
})

it('defineAsyncComponent', async () => {
  const Async = defineAsyncComponent(() => import('./HeavyComp.vue'))
  const wrapper = mount({
    components: { Async, Suspense },
    template: '<Suspense><Async /></Suspense>',
  })
  await flushPromises()
  expect(wrapper.find('.heavy-content').exists()).toBe(true)
})
```

---

## Teleport 內容測試

`<Teleport to="body">` 把內容移出 wrapper scope，`wrapper.find('.modal')` 找不到。

```ts
// 用 document 查詢 + attachTo + unmount 清理
it('shows modal', async () => {
  const wrapper = mount(App, { attachTo: document.body })
  await wrapper.find('[data-test="open-modal"]').trigger('click')
  expect(document.body.querySelector('.modal')).toBeTruthy()
  wrapper.unmount()
})

// 或 stub 掉 Teleport
mount(Comp, { global: { stubs: { Teleport: true } } })
```

---

## Snapshot 誤區

Snapshot 只驗證「輸出沒變」，不驗證「輸出正確」。改一點點都要更新 snapshot 是反訊號。

```ts
// 主體用 explicit assertion
expect(wrapper.find('.error').exists()).toBe(false)
expect(wrapper.emitted('submit')).toHaveLength(1)
expect(wrapper.emitted('submit')?.[0]).toEqual([{ name: 'John' }])
// snapshot 當輔助
expect(wrapper.html()).toMatchSnapshot()
```

---

## E2E：Playwright vs Cypress

新專案推薦 **Playwright**：原生多瀏覽器（Chromium/Firefox/WebKit）、auto-wait、平行 + sharding、現代 async/await API。詳細 best practice → `playwright-best-practices` skill。

Cypress 仍可用，多瀏覽器支援與穩定性弱於 Playwright。

---

## Nuxt 3 測試簡述

Nuxt 提供 `@nuxt/test-utils`，可在 Vitest 內 boot Nuxt app 做整合測試（`setup({ server: true })`）；server route 用 `$fetch` 直接打。具體 SSR/Nitro/auto-import 細節由 `nuxt` skill 處理。

## 延伸閱讀

- Vitest：https://vitest.dev
- Vue Test Utils：https://test-utils.vuejs.org
- Pinia Testing：https://pinia.vuejs.org/cookbook/testing.html
- Playwright：https://playwright.dev
