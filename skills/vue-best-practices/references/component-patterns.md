---
name: Vue Component Patterns
---

# Vue Component Patterns

## 目錄

- [SFC 結構最佳實踐](#sfc-結構最佳實踐)
- [Props 模式](#props-模式)
- [Emits 模式](#emits-模式)
- [Slots 插槽](#slots-插槽)
- [v-model 雙向綁定](#v-model-雙向綁定)
- [Template Refs 模板引用](#template-refs-模板引用)
- [Dynamic Components 動態元件](#dynamic-components-動態元件)
- [Async Components 非同步元件](#async-components-非同步元件)
- [Teleport 傳送門](#teleport-傳送門)

---

## SFC 結構最佳實踐

Vue SFC 建議依照 `script setup` → `template` → `style` 的順序排列。`<script setup>` 放最上方，方便快速瀏覽元件的邏輯與介面定義。

```vue
<script setup lang="ts">
import { ref } from 'vue'
import ChildComponent from './ChildComponent.vue'

const count = ref(0)
</script>

<template>
  <div class="wrapper">
    <ChildComponent :count="count" />
    <button @click="count++">增加</button>
  </div>
</template>

<style scoped>
.wrapper {
  padding: 1rem;
}
</style>
```

---

## Props 模式

### defineProps 搭配 TypeScript 型別

使用泛型語法定義 props，可獲得完整的型別推導。`withDefaults` 用於設定預設值。

```vue
<script setup lang="ts">
interface Props {
  title: string
  count?: number
  tags?: string[]
  status: 'active' | 'inactive' | 'pending'
}

const props = withDefaults(defineProps<Props>(), {
  count: 0,
  tags: () => [],
})
</script>

<template>
  <h2>{{ props.title }} ({{ props.count }})</h2>
  <span v-for="tag in props.tags" :key="tag">{{ tag }}</span>
</template>
```

### Reactive Props Destructure (Vue 3.5+)

Vue 3.5 起，從 `defineProps()` 解構出來的變數**保有反應性**——編譯器會自動把 `foo` 改寫成 `props.foo`。3.5 之前解構會凍結成一次性快照，所以同一份程式碼在兩個版本語意相反，**先確認專案的 Vue minor 版本再決定寫法**。

```vue
<script setup lang="ts">
const { foo } = defineProps<{ foo: string }>()

watchEffect(() => {
  // 3.5 之前：只跑一次
  // 3.5 之後：foo prop 變動時重跑
  console.log(foo)
})
</script>
```

3.5+ 也讓型別宣告可以直接用原生預設值語法，不再需要 `withDefaults`：

```vue
<script setup lang="ts">
interface Props {
  msg?: string
  labels?: string[]
}

const { msg = 'hello', labels = ['one', 'two'] } = defineProps<Props>()
</script>
```

> 上一節的 `withDefaults` 寫法在 3.5+ 仍然有效，維護既有檔案時沿用該檔既有風格即可；新檔優先用解構預設值。

### Props Validator 自訂驗證

當需要執行時期驗證（非僅型別檢查），使用 runtime declaration 搭配 `validator`。

```vue
<script setup lang="ts">
const props = defineProps({
  score: {
    type: Number,
    required: true,
    validator: (value: number) => value >= 0 && value <= 100,
  },
  email: {
    type: String,
    default: '',
    validator: (value: string) => value === '' || value.includes('@'),
  },
})
</script>
```

---

## Emits 模式

### defineEmits 搭配 TypeScript

型別化的 emits 確保事件名稱與 payload 的正確性。

```vue
<script setup lang="ts">
interface FormData {
  name: string
  email: string
}

const emit = defineEmits<{
  submit: [data: FormData]
  cancel: []
  'update:modelValue': [value: string]
}>()

function handleSubmit(data: FormData) {
  emit('submit', data)
}

function handleCancel() {
  emit('cancel')
}
</script>

<template>
  <form @submit.prevent="handleSubmit({ name: 'test', email: 'a@b.c' })">
    <button type="submit">送出</button>
    <button type="button" @click="handleCancel">取消</button>
  </form>
</template>
```

---

## Slots 插槽

### Default、Named、Scoped Slots

Scoped slots 可將子元件的資料暴露給父元件使用，搭配 TypeScript 可定義 slot props 型別。

```vue
<!-- DataList.vue -->
<script setup lang="ts" generic="T">
defineProps<{
  items: T[]
}>()

defineSlots<{
  default: (props: { item: T; index: number }) => any
  header: () => any
  empty: () => any
}>()
</script>

<template>
  <div class="data-list">
    <div class="header">
      <slot name="header" />
    </div>
    <template v-if="items.length">
      <div v-for="(item, index) in items" :key="index" class="item">
        <slot :item="item" :index="index" />
      </div>
    </template>
    <div v-else>
      <slot name="empty">
        <p>沒有資料</p>
      </slot>
    </div>
  </div>
</template>
```

```vue
<!-- 父元件使用 -->
<script setup lang="ts">
import DataList from './DataList.vue'

interface User { id: number; name: string; role: string }
const users: User[] = [
  { id: 1, name: 'Alice', role: 'Admin' },
  { id: 2, name: 'Bob', role: 'User' },
]
</script>

<template>
  <DataList :items="users">
    <template #header>
      <h2>使用者列表</h2>
    </template>
    <template #default="{ item, index }">
      <span>{{ index + 1 }}. {{ item.name }} - {{ item.role }}</span>
    </template>
    <template #empty>
      <p>目前無使用者</p>
    </template>
  </DataList>
</template>
```

---

## v-model 雙向綁定

### defineModel (Vue 3.4+)

`defineModel` 大幅簡化了自訂元件的 v-model 實作，不再需要手動處理 prop + emit。

```vue
<!-- RangeSlider.vue -->
<script setup lang="ts">
const min = defineModel<number>('min', { required: true })
const max = defineModel<number>('max', { required: true })
</script>

<template>
  <div class="range-slider">
    <label>最小值: <input v-model.number="min" type="range" :max="max" /></label>
    <label>最大值: <input v-model.number="max" type="range" :min="min" /></label>
    <p>範圍: {{ min }} - {{ max }}</p>
  </div>
</template>
```

```vue
<!-- 父元件使用 -->
<script setup lang="ts">
import { ref } from 'vue'
import RangeSlider from './RangeSlider.vue'

const minVal = ref(10)
const maxVal = ref(90)
</script>

<template>
  <RangeSlider v-model:min="minVal" v-model:max="maxVal" />
</template>
```

---

## Template Refs 模板引用

### useTemplateRef (Vue 3.5+)

`useTemplateRef('name')` 用字串對應 `ref="name"`，**不再要求變數名與 `ref` 屬性同名**，因此可以安全地重新命名變數、或在 `v-for` / 條件渲染中動態決定要抓哪一個。

```ts
function useTemplateRef<T>(key: string): Readonly<ShallowRef<T | null>>
```

回傳是 **readonly 的 shallow ref 且可為 `null`**——不要對它賦值，取用一律走 `?.`。

```vue
<script setup lang="ts">
import { useTemplateRef, onMounted } from 'vue'

const inputEl = useTemplateRef<HTMLInputElement>('search-input')

onMounted(() => inputEl.value?.focus())
</script>

<template>
  <input ref="search-input" />
</template>
```

3.5 之前只能靠「同名 `ref` 變數」隱式綁定（`const searchInput = ref(null)` 對應 `ref="searchInput"`）。該寫法在 3.5+ 仍可用，但改名即靜默失效——**新程式碼一律用 `useTemplateRef`**。

子元件的 ref 只暴露 `defineExpose` 宣告過的成員；`v-if` 未渲染或 `await` 之前取用皆為 `null`（見 `vue-debug-guides`）。

---

## Dynamic Components 動態元件

使用 `<component :is>` 根據條件渲染不同元件，常見於 tabs、表單步驟等場景。

```vue
<script setup lang="ts">
import { ref, shallowRef } from 'vue'
import StepOne from './StepOne.vue'
import StepTwo from './StepTwo.vue'
import StepThree from './StepThree.vue'

const steps = [StepOne, StepTwo, StepThree] as const
const currentStep = ref(0)
const activeComponent = shallowRef(steps[0])

function goTo(index: number) {
  currentStep.value = index
  activeComponent.value = steps[index]
}
</script>

<template>
  <div class="wizard">
    <nav>
      <button v-for="(_, i) in steps" :key="i" @click="goTo(i)">
        步驟 {{ i + 1 }}
      </button>
    </nav>
    <component :is="activeComponent" />
  </div>
</template>
```

---

## Async Components 非同步元件

### defineAsyncComponent + Suspense

非同步元件可延遲載入重型元件，搭配 `<Suspense>` 處理載入狀態與錯誤。

```vue
<script setup lang="ts">
import { defineAsyncComponent } from 'vue'

const HeavyChart = defineAsyncComponent({
  loader: () => import('./HeavyChart.vue'),
  loadingComponent: () => import('./ChartSkeleton.vue'),
  errorComponent: () => import('./ErrorFallback.vue'),
  delay: 200,
  timeout: 10000,
})
</script>

<template>
  <Suspense>
    <template #default>
      <HeavyChart :data="chartData" />
    </template>
    <template #fallback>
      <div class="skeleton">載入圖表中...</div>
    </template>
  </Suspense>
</template>
```

---

## Teleport 傳送門

`<Teleport>` 將元件的 DOM 渲染到指定的目標節點，常用於 modal、toast、tooltip 等需要脫離父元件 DOM 層級的場景。

```vue
<script setup lang="ts">
import { ref } from 'vue'

const showModal = ref(false)
</script>

<template>
  <button @click="showModal = true">開啟 Modal</button>

  <Teleport to="body">
    <div v-if="showModal" class="modal-overlay" @click.self="showModal = false">
      <div class="modal-content" role="dialog" aria-modal="true">
        <h2>確認操作</h2>
        <p>確定要執行此操作嗎？</p>
        <div class="modal-actions">
          <button @click="showModal = false">取消</button>
          <button @click="showModal = false">確認</button>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
}
.modal-content {
  background: white;
  border-radius: 8px;
  padding: 2rem;
  min-width: 320px;
}
</style>
```

`<Teleport>` 也支援 `disabled` 屬性，可動態控制是否啟用傳送：

```vue
<Teleport to="body" :disabled="isInline">
  <div class="popup">內容</div>
</Teleport>
```
