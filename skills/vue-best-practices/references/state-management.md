---
name: Vue State Management
---

# Vue State Management

## 目錄

- [ref vs reactive 深入比較](#ref-vs-reactive-深入比較)
- [computed 計算屬性](#computed-計算屬性)
- [watch vs watchEffect](#watch-vs-watcheffect)
- [Pinia 狀態管理](#pinia-狀態管理)
- [VueUse 常用 Composables](#vueuse-常用-composables)
- [Provide / Inject 依賴注入](#provide--inject-依賴注入)

---

## ref vs reactive 深入比較

`ref` 適用於原始值與需要重新賦值的場景；`reactive` 適用於物件，但不可解構否則失去響應性。

```vue
<script setup lang="ts">
import { ref, reactive, toRef, toRefs } from 'vue'

// ref：適用於原始值，透過 .value 存取
const count = ref(0)
count.value++

// ref：也可包裹物件，整個替換仍保持響應性
const user = ref<{ name: string; age: number } | null>(null)
user.value = { name: 'Alice', age: 30 }

// reactive：適用於物件，直接存取屬性
const form = reactive({
  email: '',
  password: '',
  remember: false,
})
form.email = 'test@example.com'

// 解構 reactive 會失去響應性
// const { email } = form  // email 不是響應式的

// 正確做法：使用 toRefs
const { email, password } = toRefs(form)
email.value = 'new@example.com' // 仍然是響應式的

// toRef：從 reactive 物件取出單一屬性
const rememberRef = toRef(form, 'remember')
</script>
```

**選擇原則**：優先使用 `ref`。`ref` 在重新賦值、傳遞給 composables、以及作為函式回傳值時行為更一致。

---

## computed 計算屬性

### 快取行為與 Writable Computed

`computed` 會快取計算結果，只有依賴變更時才重新計算。method 每次呼叫都會重新執行。

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const firstName = ref('John')
const lastName = ref('Doe')

// 唯讀 computed
const fullName = computed(() => `${firstName.value} ${lastName.value}`)

// 可寫入的 computed
const fullNameWritable = computed({
  get: () => `${firstName.value} ${lastName.value}`,
  set: (value: string) => {
    const [first, ...rest] = value.split(' ')
    firstName.value = first
    lastName.value = rest.join(' ')
  },
})

// 搭配泛型
const items = ref([3, 1, 4, 1, 5])
const sorted = computed<number[]>(() => [...items.value].sort((a, b) => a - b))
</script>
```

---

## watch vs watchEffect

### watch：明確指定監聽來源

```vue
<script setup lang="ts">
import { ref, watch, watchEffect } from 'vue'

const searchQuery = ref('')
const selectedId = ref<number | null>(null)

// 監聽單一來源，含 immediate 與 deep
watch(searchQuery, (newVal, oldVal) => {
  console.log(`搜尋: ${oldVal} -> ${newVal}`)
}, { immediate: true })

// 監聽多個來源
watch([searchQuery, selectedId], ([query, id], [prevQuery, prevId]) => {
  console.log('查詢或選中項變更')
})

// deep watching 物件
const filters = ref({ status: 'all', sort: 'date' })
watch(filters, (newFilters) => {
  fetchData(newFilters)
}, { deep: true })

// flush: 'post' 確保在 DOM 更新後執行
watch(searchQuery, () => {
  // 此時 DOM 已更新
}, { flush: 'post' })
</script>
```

### watchEffect：自動追蹤依賴 + cleanup

```vue
<script setup lang="ts">
import { ref, watchEffect } from 'vue'

const userId = ref(1)

watchEffect((onCleanup) => {
  const controller = new AbortController()

  fetch(`/api/users/${userId.value}`, { signal: controller.signal })
    .then(res => res.json())
    .then(data => console.log(data))

  onCleanup(() => controller.abort())
})
</script>
```

### onWatcherCleanup (Vue 3.5+)

3.5 起可改用 `onWatcherCleanup()`，不必把 `onCleanup` 當參數往下傳——它能在 watcher 的**同步**呼叫堆疊中任何一層註冊清理，所以抽出去的 helper 函式也能自己收尾。

```vue
<script setup lang="ts">
import { ref, watch, onWatcherCleanup } from 'vue'

const userId = ref(1)

function fetchUser(id: number) {
  const controller = new AbortController()
  onWatcherCleanup(() => controller.abort())   // 在 helper 內註冊，不需傳 onCleanup
  return fetch(`/api/users/${id}`, { signal: controller.signal })
}

watch(userId, id => fetchUser(id))
</script>
```

必須在 watcher callback 的同步階段呼叫；`await` 之後才呼叫會拿不到當前 watcher，靜默失效。`onCleanup` 參數寫法在 3.5+ 仍然有效，維護既有檔案時沿用即可。

---

## Pinia 狀態管理

### Setup Store（推薦）vs Option Store

Setup Store 更靈活，可直接使用 composables；Option Store 結構較固定，適合簡單場景。

```ts
// stores/useCartStore.ts - Setup Store（推薦）
import { defineStore } from 'pinia'
import { ref, computed } from 'vue'

interface CartItem {
  id: number
  name: string
  price: number
  quantity: number
}

export const useCartStore = defineStore('cart', () => {
  const items = ref<CartItem[]>([])

  // Getter（computed）
  const totalPrice = computed(() =>
    items.value.reduce((sum, item) => sum + item.price * item.quantity, 0)
  )
  const itemCount = computed(() =>
    items.value.reduce((sum, item) => sum + item.quantity, 0)
  )

  // Actions
  function addItem(product: Omit<CartItem, 'quantity'>) {
    const existing = items.value.find(i => i.id === product.id)
    if (existing) {
      existing.quantity++
    } else {
      items.value.push({ ...product, quantity: 1 })
    }
  }

  function removeItem(id: number) {
    items.value = items.value.filter(i => i.id !== id)
  }

  function clear() {
    items.value = []
  }

  return { items, totalPrice, itemCount, addItem, removeItem, clear }
})
```

### Pinia Persisted State 插件

使用 `pinia-plugin-persistedstate` 自動將 store 資料持久化到 localStorage。

```ts
// main.ts
import { createPinia } from 'pinia'
import piniaPluginPersistedstate from 'pinia-plugin-persistedstate'

const pinia = createPinia()
pinia.use(piniaPluginPersistedstate)

// stores/useAuthStore.ts
export const useAuthStore = defineStore('auth', () => {
  const token = ref<string | null>(null)
  const user = ref<{ id: number; name: string } | null>(null)
  return { token, user }
}, {
  persist: {
    pick: ['token'],        // 只持久化 token
    storage: localStorage,
  },
})
```

---

## VueUse 常用 Composables

VueUse 提供大量實用的 composables，以下列出最常用的。

```vue
<script setup lang="ts">
import {
  useFetch,
  useLocalStorage,
  useDark,
  useToggle,
  useIntersectionObserver,
  useVModel,
  useEventListener,
  useDebounceFn,
  useThrottleFn,
  useClipboard,
  useWindowSize,
  useElementSize,
  onClickOutside,
  useMediaQuery,
  useOnline,
  useTitle,
  useUrlSearchParams,
  useStorage,
  useBreakpoints,
  useScroll,
  breakpointsTailwind,
} from '@vueuse/core'
import { ref } from 'vue'

// 1. useFetch - 資料請求
const { data, error, isFetching } = useFetch('/api/users').json()

// 2. useLocalStorage - 本地儲存
const theme = useLocalStorage('theme', 'light')

// 3. useDark - 深色模式切換
const isDark = useDark()
const toggleDark = useToggle(isDark)

// 4. useDebounceFn - 防抖
const debouncedSearch = useDebounceFn((query: string) => {
  fetchResults(query)
}, 300)

// 5. useClipboard - 剪貼簿
const { copy, copied } = useClipboard()

// 6. onClickOutside - 點擊外部偵測
const dropdownRef = ref<HTMLElement | null>(null)
onClickOutside(dropdownRef, () => { /* 關閉下拉選單 */ })

// 7. useWindowSize - 視窗尺寸
const { width, height } = useWindowSize()

// 8. useMediaQuery - 媒體查詢
const isLargeScreen = useMediaQuery('(min-width: 1024px)')

// 9. useOnline - 網路狀態
const isOnline = useOnline()

// 10. useBreakpoints - 響應式斷點
const breakpoints = useBreakpoints(breakpointsTailwind)
const isMobile = breakpoints.smaller('sm')
</script>
```

---

## Provide / Inject 依賴注入

### 型別化的 Injection Keys

使用 `InjectionKey` 確保 provide/inject 的型別安全。適合跨層級元件傳遞資料。

```ts
// injection-keys.ts
import type { InjectionKey, Ref } from 'vue'

export interface ThemeConfig {
  primaryColor: string
  borderRadius: string
  isDark: Ref<boolean>
}

export const themeKey: InjectionKey<ThemeConfig> = Symbol('theme')
export const apiBaseUrlKey: InjectionKey<string> = Symbol('apiBaseUrl')
```

```vue
<!-- 提供者（祖先元件） -->
<script setup lang="ts">
import { provide, ref } from 'vue'
import { themeKey, apiBaseUrlKey } from './injection-keys'

const isDark = ref(false)

provide(themeKey, {
  primaryColor: '#3b82f6',
  borderRadius: '8px',
  isDark,
})
provide(apiBaseUrlKey, 'https://api.example.com')
</script>
```

```vue
<!-- 消費者（後代元件） -->
<script setup lang="ts">
import { inject } from 'vue'
import { themeKey, apiBaseUrlKey } from './injection-keys'

// 有預設值的 inject 不會回傳 undefined
const theme = inject(themeKey, {
  primaryColor: '#000',
  borderRadius: '4px',
  isDark: ref(false),
})

const apiBaseUrl = inject(apiBaseUrlKey, 'http://localhost:3000')
</script>

<template>
  <div :style="{ color: theme.primaryColor, borderRadius: theme.borderRadius }">
    <p>API: {{ apiBaseUrl }}</p>
    <p>深色模式: {{ theme.isDark }}</p>
  </div>
</template>
```
