---
name: Vue Performance Optimization
---

# Vue Performance Optimization

## 目錄

- [v-once 靜態內容優化](#v-once-靜態內容優化)
- [v-memo 條件性跳過重新渲染](#v-memo-條件性跳過重新渲染)
- [shallowRef / shallowReactive](#shallowref--shallowreactive)
- [KeepAlive 元件快取](#keepalive-元件快取)
- [Virtual Scrolling 虛擬捲動](#virtual-scrolling-虛擬捲動)
- [Async Components + Suspense 延遲載入](#async-components--suspense-延遲載入)
- [computed vs method 效能差異](#computed-vs-method-效能差異)
- [Tree-shaking Vue Imports](#tree-shaking-vue-imports)
- [Bundle 分析工具](#bundle-分析工具)

---

## v-once 靜態內容優化

`v-once` 讓元素及其子樹只渲染一次，之後跳過所有更新。適用於純靜態的內容區塊。

```vue
<template>
  <!-- 頁尾版權資訊永遠不會變，用 v-once 避免不必要的 diff -->
  <footer v-once>
    <p>&copy; 2024 MyApp. All rights reserved.</p>
    <nav>
      <a href="/privacy">隱私政策</a>
      <a href="/terms">服務條款</a>
    </nav>
  </footer>

  <!-- 大量靜態選項列表 -->
  <select>
    <option v-for="country in countries" :key="country.code" v-once :value="country.code">
      {{ country.name }}
    </option>
  </select>
</template>
```

**注意**：僅在內容確實不會變更時使用。過度使用 `v-once` 可能導致 UI 不同步的 bug。

---

## v-memo 條件性跳過重新渲染

`v-memo` 可為列表中的每個項目設定條件，只有條件值變更時才重新渲染該項。對大型列表效能提升顯著。

```vue
<script setup lang="ts">
import { ref } from 'vue'

interface Item {
  id: number
  name: string
  selected: boolean
}

const items = ref<Item[]>(/* 大量資料 */)
const selectedId = ref<number | null>(null)

function toggleSelect(item: Item) {
  item.selected = !item.selected
  selectedId.value = item.selected ? item.id : null
}
</script>

<template>
  <!-- 只有當 item.selected 或 selectedId 變更時才重新渲染該項 -->
  <div
    v-for="item in items"
    :key="item.id"
    v-memo="[item.selected, selectedId === item.id]"
    :class="{ active: item.selected }"
    @click="toggleSelect(item)"
  >
    {{ item.name }}
  </div>
</template>
```

---

## shallowRef / shallowReactive

當物件結構龐大但只需追蹤頂層變更時，使用 `shallowRef` 或 `shallowReactive` 避免深層遞迴的響應式轉換。

```vue
<script setup lang="ts">
import { shallowRef, triggerRef, shallowReactive } from 'vue'

// shallowRef：只追蹤 .value 的替換，不追蹤內部屬性變更
const largeDataset = shallowRef<Array<{ id: number; values: number[] }>>([])

async function loadData() {
  const response = await fetch('/api/large-dataset')
  // 整個替換會觸發更新
  largeDataset.value = await response.json()
}

function updateInPlace() {
  // 直接修改內部不會觸發更新
  largeDataset.value[0].values.push(999)
  // 需要手動觸發
  triggerRef(largeDataset)
}

// shallowReactive：只追蹤頂層屬性
const config = shallowReactive({
  theme: 'dark',          // 響應式
  nested: { color: 'red' } // nested.color 不是響應式的
})
</script>

<template>
  <p>資料筆數: {{ largeDataset.length }}</p>
</template>
```

**使用場景**：GeoJSON 資料、大型表格資料、第三方函式庫的實例物件（如 Chart.js、Monaco Editor）。

---

## KeepAlive 元件快取

`<KeepAlive>` 快取非活動元件的狀態，避免每次切換時重建。搭配 `include`/`exclude`/`max` 控制快取策略。

```vue
<script setup lang="ts">
import { ref, onActivated, onDeactivated } from 'vue'
import TabA from './TabA.vue'
import TabB from './TabB.vue'
import TabC from './TabC.vue'

const currentTab = ref('TabA')
const tabs = { TabA, TabB, TabC }
</script>

<template>
  <nav>
    <button
      v-for="(_, name) in tabs"
      :key="name"
      :class="{ active: currentTab === name }"
      @click="currentTab = name"
    >
      {{ name }}
    </button>
  </nav>

  <!-- 最多快取 5 個，只快取 TabA 和 TabB -->
  <KeepAlive :include="['TabA', 'TabB']" :max="5">
    <component :is="tabs[currentTab]" />
  </KeepAlive>
</template>
```

```vue
<!-- 子元件中使用 activated/deactivated 生命週期 -->
<script setup lang="ts">
import { onActivated, onDeactivated } from 'vue'

onActivated(() => {
  // 元件從快取中恢復時呼叫，可用於刷新資料
  refreshData()
})

onDeactivated(() => {
  // 元件被快取（離開）時呼叫，可用於暫停計時器
  pausePolling()
})
</script>
```

---

## Virtual Scrolling 虛擬捲動

當列表項目超過數百筆時，虛擬捲動只渲染可見區域的 DOM 節點，大幅降低記憶體與渲染成本。

```vue
<!-- 使用 @tanstack/vue-virtual -->
<script setup lang="ts">
import { ref } from 'vue'
import { useVirtualizer } from '@tanstack/vue-virtual'

const items = ref(Array.from({ length: 50000 }, (_, i) => ({
  id: i,
  text: `Item #${i}`,
})))

const parentRef = ref<HTMLElement | null>(null)

const virtualizer = useVirtualizer({
  count: items.value.length,
  getScrollElement: () => parentRef.value,
  estimateSize: () => 40,
  overscan: 5,
})
</script>

<template>
  <div ref="parentRef" style="height: 500px; overflow-y: auto;">
    <div :style="{ height: `${virtualizer.getTotalSize()}px`, position: 'relative' }">
      <div
        v-for="row in virtualizer.getVirtualItems()"
        :key="row.key"
        :style="{
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: `${row.size}px`,
          transform: `translateY(${row.start}px)`,
        }"
      >
        {{ items[row.index].text }}
      </div>
    </div>
  </div>
</template>
```

---

## Async Components + Suspense 延遲載入

將不在首屏的重型元件拆分為非同步載入，降低初始 bundle 大小。

```vue
<script setup lang="ts">
import { defineAsyncComponent, ref } from 'vue'

const showDashboard = ref(false)

// 延遲載入：只有使用時才下載
const HeavyDashboard = defineAsyncComponent(() =>
  import('./HeavyDashboard.vue')
)

const RichTextEditor = defineAsyncComponent({
  loader: () => import('./RichTextEditor.vue'),
  delay: 200,       // 200ms 後才顯示 loading
  timeout: 30000,   // 30 秒逾時
})
</script>

<template>
  <button @click="showDashboard = true">開啟儀表板</button>

  <Suspense v-if="showDashboard">
    <template #default>
      <HeavyDashboard />
    </template>
    <template #fallback>
      <div class="loading-skeleton">載入中...</div>
    </template>
  </Suspense>
</template>
```

---

## computed vs method 效能差異

`computed` 會快取結果，只在依賴變更時重新計算。`method` 每次 template 渲染都會重新呼叫。

```vue
<script setup lang="ts">
import { ref, computed } from 'vue'

const list = ref(Array.from({ length: 1000 }, (_, i) => ({ id: i, active: i % 2 === 0 })))

// computed：只在 list 變更時重新計算，多次引用也只算一次
const activeCount = computed(() => {
  console.log('computed 執行') // 只印一次
  return list.value.filter(item => item.active).length
})

// method：每次被 template 引用都會重新執行
function getActiveCount() {
  console.log('method 執行') // 每次渲染都印
  return list.value.filter(item => item.active).length
}
</script>

<template>
  <!-- computed：快取，只算一次 -->
  <p>Active (computed): {{ activeCount }}</p>
  <p>Again: {{ activeCount }}</p>

  <!-- method：每次引用都重算 -->
  <p>Active (method): {{ getActiveCount() }}</p>
  <p>Again: {{ getActiveCount() }}</p>
</template>
```

**原則**：template 中需要多次引用的衍生資料，一律用 `computed`。

---

## Tree-shaking Vue Imports

Vue 3 支援 tree-shaking，只匯入實際使用的 API，未使用的不會進入 production bundle。

```ts
// 正確：具名匯入，可 tree-shake
import { ref, computed, watch, onMounted } from 'vue'

// 避免：匯入整個模組（無法 tree-shake）
// import * as Vue from 'vue'

// Vite 預設已最佳化，確認 vite.config.ts 沒有意外的全域匯入
```

在 `vite.config.ts` 中啟用 auto-import 可進一步減少手動匯入：

```ts
// vite.config.ts
import AutoImport from 'unplugin-auto-import/vite'

export default defineConfig({
  plugins: [
    AutoImport({
      imports: ['vue', 'vue-router', 'pinia'],
      dts: 'src/auto-imports.d.ts',
    }),
  ],
})
```

---

## Bundle 分析工具

使用 `vite-bundle-visualizer` 或 `rollup-plugin-visualizer` 視覺化分析打包結果，找出過大的依賴。

```bash
# 安裝
npm install -D rollup-plugin-visualizer

# 或直接使用 npx
npx vite-bundle-visualizer
```

```ts
// vite.config.ts
import { visualizer } from 'rollup-plugin-visualizer'

export default defineConfig({
  plugins: [
    visualizer({
      open: true,
      filename: 'dist/stats.html',
      gzipSize: true,
      brotliSize: true,
    }),
  ],
  build: {
    rollupOptions: {
      output: {
        // 手動拆分第三方套件
        manualChunks: {
          'vendor-vue': ['vue', 'vue-router', 'pinia'],
          'vendor-ui': ['@headlessui/vue', 'tailwind-merge'],
        },
      },
    },
  },
})
```

**常見優化手段**：
- 檢查是否有意外的全量匯入（如 lodash 應改用 lodash-es）
- 拆分路由級別的 chunk（搭配 Vue Router lazy loading）
- 使用 `manualChunks` 將穩定的第三方套件分離
