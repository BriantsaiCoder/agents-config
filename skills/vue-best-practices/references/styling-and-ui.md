---
name: Vue Styling and UI Libraries
---

# Vue Styling and UI Libraries

## 目錄

- [Scoped Style 深入解析](#scoped-style-深入解析)
- [CSS Modules](#css-modules)
- [CSS v-bind 響應式樣式](#css-v-bind-響應式樣式)
- [Tailwind CSS + Vue 整合](#tailwind-css--vue-整合)
- [Headless UI Vue](#headless-ui-vue)
- [Reka UI](#reka-ui)
- [PrimeVue 與 Element Plus](#primevue-與-element-plus)

---

## Scoped Style 深入解析

`<style scoped>` 透過在元素上添加唯一的 data attribute（如 `data-v-7ba5bd90`）來實現樣式隔離。三個特殊選擇器可突破隔離範圍。

### :deep() 穿透子元件

影響子元件內部的樣式，常用於覆寫第三方元件的預設樣式。

```vue
<style scoped>
/* 只影響當前元件的 .title */
.title {
  font-size: 1.5rem;
}

/* 穿透：影響子元件內部的 .el-input__inner */
.form-wrapper :deep(.el-input__inner) {
  border-color: #3b82f6;
}

/* 穿透到深層子元件 */
.container :deep(.child-component .nested-element) {
  color: red;
}
</style>
```

### :slotted() 影響 slot 內容

父元件傳入的 slot 內容預設不受子元件 scoped style 影響，用 `:slotted()` 可以選取。

```vue
<!-- Card.vue -->
<template>
  <div class="card">
    <slot />
  </div>
</template>

<style scoped>
.card {
  padding: 1rem;
  border: 1px solid #e5e7eb;
}

/* 選取 slot 中傳入的 <p> 標籤 */
.card :slotted(p) {
  margin: 0;
  color: #6b7280;
}
</style>
```

### :global() 全域樣式

在 scoped style 區塊中定義全域樣式，不會加上 data attribute。

```vue
<style scoped>
/* 僅限當前元件 */
.local-class {
  color: blue;
}

/* 全域：影響整個應用 */
:global(.toast-notification) {
  position: fixed;
  top: 1rem;
  right: 1rem;
  z-index: 9999;
}
</style>
```

---

## CSS Modules

CSS Modules 將 class name 編譯為唯一的 hash，避免全域衝突。透過 `$style` 物件存取。

```vue
<script setup lang="ts">
import { useCssModule } from 'vue'

// 預設 module
const style = useCssModule()

// 具名 module
const theme = useCssModule('theme')
</script>

<template>
  <div :class="$style.container">
    <h1 :class="[$style.title, $style.primary]">標題</h1>
    <p :class="{ [$style.highlight]: isActive }">內容</p>
  </div>
</template>

<style module>
.container {
  max-width: 800px;
  margin: 0 auto;
}
.title {
  font-size: 2rem;
}
.primary {
  color: #3b82f6;
}
.highlight {
  background-color: #fef3c7;
}
</style>

<!-- 具名 CSS Module -->
<style module="theme">
.dark {
  background-color: #1f2937;
  color: #f9fafb;
}
.light {
  background-color: #ffffff;
  color: #111827;
}
</style>
```

---

## CSS v-bind 響應式樣式

`v-bind()` 可在 `<style>` 中直接使用 `<script setup>` 的響應式變數，值變更時樣式自動更新。

```vue
<script setup lang="ts">
import { ref } from 'vue'

const primaryColor = ref('#3b82f6')
const fontSize = ref(16)
const theme = ref({
  bg: '#ffffff',
  text: '#111827',
  radius: '8px',
})

function toggleTheme() {
  if (theme.value.bg === '#ffffff') {
    theme.value = { bg: '#1f2937', text: '#f9fafb', radius: '12px' }
  } else {
    theme.value = { bg: '#ffffff', text: '#111827', radius: '8px' }
  }
}
</script>

<template>
  <div class="themed-box">
    <p>動態主題色: {{ primaryColor }}</p>
    <input v-model="primaryColor" type="color" />
    <input v-model.number="fontSize" type="range" min="12" max="32" />
    <button @click="toggleTheme">切換主題</button>
  </div>
</template>

<style scoped>
.themed-box {
  background-color: v-bind('theme.bg');
  color: v-bind('theme.text');
  border-radius: v-bind('theme.radius');
  font-size: v-bind("fontSize + 'px'");
  border: 2px solid v-bind(primaryColor);
  padding: 1.5rem;
  transition: all 0.3s ease;
}
</style>
```

---

## Tailwind CSS + Vue 整合

### Class Binding 模式

Vue 的動態 class 綁定與 Tailwind 搭配的常見寫法。

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const isActive = ref(false)
const variant = ref<'primary' | 'danger' | 'ghost'>('primary')

// 使用 computed 組合複雜的 class
const buttonClasses = computed(() => {
  const base = 'inline-flex items-center px-4 py-2 rounded-lg font-medium transition-colors'
  const variants = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700',
    danger: 'bg-red-600 text-white hover:bg-red-700',
    ghost: 'bg-transparent text-gray-700 hover:bg-gray-100',
  }
  return `${base} ${variants[variant.value]}`
})
</script>

<template>
  <!-- 靜態 + 動態 class -->
  <div
    class="rounded-lg border p-4"
    :class="{
      'border-blue-500 bg-blue-50': isActive,
      'border-gray-200 bg-white': !isActive,
    }"
  >
    內容
  </div>

  <!-- computed class -->
  <button :class="buttonClasses">按鈕</button>

  <!-- 陣列語法 -->
  <span :class="['text-sm', isActive ? 'text-green-600' : 'text-gray-400']">
    狀態
  </span>
</template>
```

### @apply 在 SFC 中使用

```vue
<style scoped>
.card {
  @apply rounded-xl border border-gray-200 bg-white p-6 shadow-sm;
  @apply hover:shadow-md transition-shadow;
}

.card-title {
  @apply text-lg font-semibold text-gray-900 mb-2;
}
</style>
```

**建議**：優先在 template 使用 utility class，只在需要複用的元件級樣式使用 `@apply`。搭配 `tailwind-merge` 或 `clsx` 處理 class 衝突。

```ts
// utils/cn.ts - 常見的 className 合併工具
import { twMerge } from 'tailwind-merge'
import { clsx, type ClassValue } from 'clsx'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

---

## Headless UI Vue

Headless UI 提供完全無樣式、可存取性完備的 UI 元件，適合搭配 Tailwind CSS 自訂外觀。

### Dialog（Modal）

```vue
<script setup lang="ts">
import { ref } from 'vue'
import {
  Dialog,
  DialogPanel,
  DialogTitle,
  DialogDescription,
  TransitionRoot,
  TransitionChild,
} from '@headlessui/vue'

const isOpen = ref(false)
</script>

<template>
  <button @click="isOpen = true">開啟對話框</button>

  <TransitionRoot :show="isOpen" as="template">
    <Dialog @close="isOpen = false" class="relative z-50">
      <TransitionChild
        enter="ease-out duration-300" enter-from="opacity-0" enter-to="opacity-100"
        leave="ease-in duration-200" leave-from="opacity-100" leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/30" aria-hidden="true" />
      </TransitionChild>

      <div class="fixed inset-0 flex items-center justify-center p-4">
        <TransitionChild
          enter="ease-out duration-300" enter-from="opacity-0 scale-95" enter-to="opacity-100 scale-100"
          leave="ease-in duration-200" leave-from="opacity-100 scale-100" leave-to="opacity-0 scale-95"
        >
          <DialogPanel class="w-full max-w-md rounded-xl bg-white p-6 shadow-xl">
            <DialogTitle class="text-lg font-bold">刪除確認</DialogTitle>
            <DialogDescription class="mt-2 text-gray-600">
              此操作無法復原，確定要刪除嗎？
            </DialogDescription>
            <div class="mt-4 flex gap-3 justify-end">
              <button class="px-4 py-2 rounded-lg bg-gray-100" @click="isOpen = false">取消</button>
              <button class="px-4 py-2 rounded-lg bg-red-600 text-white" @click="isOpen = false">刪除</button>
            </div>
          </DialogPanel>
        </TransitionChild>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
```

### Listbox（Select）

```vue
<script setup lang="ts">
import { ref } from 'vue'
import { Listbox, ListboxButton, ListboxOptions, ListboxOption } from '@headlessui/vue'

const people = [
  { id: 1, name: 'Alice' },
  { id: 2, name: 'Bob' },
  { id: 3, name: 'Charlie' },
]
const selected = ref(people[0])
</script>

<template>
  <Listbox v-model="selected">
    <div class="relative">
      <ListboxButton class="w-full rounded-lg border px-4 py-2 text-left">
        {{ selected.name }}
      </ListboxButton>
      <ListboxOptions class="absolute mt-1 w-full rounded-lg border bg-white shadow-lg">
        <ListboxOption
          v-for="person in people"
          :key="person.id"
          :value="person"
          v-slot="{ active, selected: isSelected }"
          as="template"
        >
          <li :class="['px-4 py-2 cursor-pointer', active ? 'bg-blue-100' : '']">
            {{ person.name }} {{ isSelected ? '✓' : '' }}
          </li>
        </ListboxOption>
      </ListboxOptions>
    </div>
  </Listbox>
</template>
```

---

## Reka UI

Reka UI（原 Radix Vue，2024 更名）是 Radix UI 的 Vue 移植版，提供更多元件種類（Tooltip、Popover、Accordion、Tabs 等），同樣是 headless 設計，可存取性極佳。新專案一律裝 `reka-ui`；既有專案若還停在 `radix-vue`，遷移時 import 來源 `radix-vue` → `reka-ui`、Nuxt module `radix-vue/nuxt` → `reka-ui/nuxt`、CSS 變數 `--radix-*` → `--reka-*`、屬性選擇器 `[data-radix-*]` → `[data-reka-*]` 要一併換。

```vue
<script setup lang="ts">
import { AccordionContent, AccordionHeader, AccordionItem, AccordionRoot, AccordionTrigger } from 'reka-ui'

const faqs = [
  { id: '1', question: '如何開始？', answer: '安裝套件後參考文件即可快速上手。' },
  { id: '2', question: '支援 SSR 嗎？', answer: '是的，完整支援 Nuxt 3 的 SSR。' },
]
</script>

<template>
  <AccordionRoot type="single" collapsible class="w-full max-w-md">
    <AccordionItem v-for="faq in faqs" :key="faq.id" :value="faq.id" class="border-b">
      <AccordionHeader>
        <AccordionTrigger class="w-full py-4 text-left font-medium hover:underline">
          {{ faq.question }}
        </AccordionTrigger>
      </AccordionHeader>
      <AccordionContent class="pb-4 text-gray-600">
        {{ faq.answer }}
      </AccordionContent>
    </AccordionItem>
  </AccordionRoot>
</template>
```

**Reka UI vs Headless UI**：Reka UI 元件種類更多（30+），社群活躍度高，是建立設計系統的首選。Headless UI 元件較少但由 Tailwind Labs 官方維護，與 Tailwind 整合度最高。

---

## PrimeVue 與 Element Plus

### 何時選用完整元件庫

- **PrimeVue**：企業應用首選，80+ 元件，內建多種主題（Material、Bootstrap 風格），支援 Tailwind 主題（`@primevue/themes`）。適合需要大量 DataTable、表單元件的後台管理系統。
- **Element Plus**：⛔ 新專案禁用。中文生態雖完整；僅維護既有採用專案。

```vue
<!-- PrimeVue DataTable 範例 -->
<script setup lang="ts">
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import { ref } from 'vue'

const products = ref([
  { name: '產品A', category: '電子', price: 1200 },
  { name: '產品B', category: '服飾', price: 800 },
])
</script>

<template>
  <DataTable :value="products" paginator :rows="10" stripedRows>
    <Column field="name" header="名稱" sortable />
    <Column field="category" header="類別" sortable />
    <Column field="price" header="價格" sortable>
      <template #body="{ data }">
        NT$ {{ data.price.toLocaleString() }}
      </template>
    </Column>
  </DataTable>
</template>
```

**選擇原則**：沿用 repo 已安裝的 component system 與 tokens。Naive UI 適合 styled + TypeScript/theme 完整的需求；Reka UI / Headless UI 適合高度自訂外觀；PrimeVue 適合大量 DataTable 等重型後台元件。Greenfield 預設與禁用清單由 host/repo rules 決定，不在 portable skill 複製。
