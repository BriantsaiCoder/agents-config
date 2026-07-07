# Vue Router 4

Vue Router 4 與 Vue 3 整合緊密。本文件涵蓋設定、Navigation Guards、Lifecycle 互動陷阱與常見坑。

## 目錄

- [Typed Routes 與 Lazy Loading](#typed-routes-與-lazy-loading)
- [Navigation Guards](#navigation-guards)
- [In-component guards](#in-component-guards)
- [Param 變更陷阱](#param-變更陷阱)
- [清理 timer / listener / WebSocket](#清理-timer--listener--websocket)
- [Nuxt 3 路由整合](#nuxt-3-路由整合)
- [何時用 Vue Router](#何時用-vue-router)

---

## Typed Routes 與 Lazy Loading

```ts
// router/index.ts
import { createRouter, createWebHistory, type RouteRecordRaw } from 'vue-router'

const routes: RouteRecordRaw[] = [
  { path: '/', name: 'home', component: () => import('@/views/HomeView.vue') },
  {
    path: '/users/:id',
    name: 'user-detail',
    component: () => import('@/views/UserDetail.vue'),
    props: true,
    meta: { requiresAuth: true },
  },
  {
    path: '/admin',
    component: () => import('@/layouts/AdminLayout.vue'),
    meta: { requiresAuth: true, roles: ['admin'] },
    children: [
      { path: '', name: 'admin-dashboard', component: () => import('@/views/admin/Dashboard.vue') },
      { path: 'users', name: 'admin-users', component: () => import('@/views/admin/Users.vue') },
    ],
  },
  { path: '/:pathMatch(.*)*', name: 'not-found', component: () => import('@/views/NotFound.vue') },
]

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes,
  scrollBehavior(to, from, savedPosition) {
    return savedPosition ?? { top: 0 }
  },
})

export default router
```

最佳實踐：
- Lazy loading：`component: () => import(...)`
- 統一 named routes（重構安全），不寫死 path 字串
- 用 `meta` 標 `requiresAuth` / `title` / `layout` / `roles`

---

## Navigation Guards

### `next()` 已過時 — 改 `return`

```ts
// ❌ 舊
router.beforeEach((to, from, next) => {
  if (!isLoggedIn()) next('/login')
  else next()
})

// ✅ 新（return 路徑物件 / 字串 / false / undefined）
router.beforeEach((to) => {
  if (!isLoggedIn()) return '/login'
})
```

### Async guard 必須 `await`

```ts
// ❌ fetch 未 await，guard 立刻 return → 權限檢查失效
router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    fetch('/api/check-auth')
    return true
  }
})

// ✅
router.beforeEach(async (to) => {
  if (to.meta.requiresAuth) {
    const res = await fetch('/api/check-auth')
    if (!res.ok) return '/login'
  }
})
```

### 避免重導向迴圈

```ts
// ❌ 從 /login 又被拉回 /login
router.beforeEach((to) => {
  if (!isLoggedIn()) return '/login'
})

// ✅ 排除 login 本身
router.beforeEach((to) => {
  if (to.path === '/login') return
  if (!isLoggedIn()) return '/login'
})
```

### 完整 guard 設定範例

```ts
// router/guards.ts
import type { Router } from 'vue-router'
import { useAuthStore } from '@/stores/useAuthStore'

export function setupGuards(router: Router) {
  router.beforeEach((to) => {
    const auth = useAuthStore()
    if (to.meta.requiresAuth && !auth.isAuthenticated) {
      return { name: 'login', query: { redirect: to.fullPath } }
    }
    const requiredRoles = to.meta.roles as string[] | undefined
    if (requiredRoles && !requiredRoles.some(role => auth.hasRole(role))) {
      return { name: 'forbidden' }
    }
  })

  router.afterEach((to) => {
    document.title = (to.meta.title as string) ?? 'My App'
  })
}
```

---

## In-component guards

### `beforeRouteEnter` 裡 `this` 是 undefined

`beforeRouteEnter` 在元件 instance 創建**之前**觸發。Options API 用 `next(vm => ...)`；Composition API 改用 `onBeforeRouteUpdate` / `onBeforeRouteLeave` + 元件內 ref。

```vue
<script setup lang="ts">
import { onBeforeRouteLeave } from 'vue-router'
import { ref } from 'vue'

const hasUnsavedChanges = ref(false)

onBeforeRouteLeave(() => {
  if (hasUnsavedChanges.value) {
    if (!window.confirm('有未儲存的變更，確定離開嗎？')) return false
  }
})
</script>
```

---

## Param 變更陷阱

### 同一 route 不同 params 不觸發 `beforeEnter`

`beforeEnter` 只在「進入該 route」時跑一次，同一 route 內 params 改變不會重新觸發。用全域 `beforeEach` 或元件內 watch。

```ts
router.beforeEach((to, from) => {
  if (to.name === from.name && to.params.id !== from.params.id) {
    // params 變更
  }
})
```

### 同一 route params 改變不觸發 component lifecycle

`/user/1` → `/user/2` 時 `onMounted` 不會再跑，Vue 複用同一個元件實例。

```vue
<script setup lang="ts">
import { ref, watch } from 'vue'
import { useRoute } from 'vue-router'

const route = useRoute()
const user = ref(null)

// 方案 A：watch（推薦）
watch(() => route.params.id, async (id) => {
  user.value = await fetchUser(id as string)
}, { immediate: true })
</script>

<!-- 方案 B：父層 :key 強制重 mount（重量級，慎用） -->
<router-view :key="$route.fullPath" />
```

---

## 清理 timer / listener / WebSocket

切頁後仍 polling、`Cannot read property of null` 等症狀 → 在 `onUnmounted` 清理。或直接用 VueUse 的自動清理 helper。

```vue
<script setup lang="ts">
import { onMounted, onUnmounted } from 'vue'

let timer: number | null = null
onMounted(() => { timer = window.setInterval(fetchStatus, 5000) })
onUnmounted(() => { if (timer) clearInterval(timer) })

// 或 VueUse — 自動 unmount 清理
import { useIntervalFn } from '@vueuse/core'
useIntervalFn(fetchStatus, 5000)
</script>
```

---

## Nuxt 3 路由整合

Nuxt 3 file-based routing；middleware 用 `defineNuxtRouteMiddleware`。

```ts
// middleware/auth.ts
export default defineNuxtRouteMiddleware((to) => {
  const { loggedIn } = useUserSession()
  if (!loggedIn.value && to.path !== '/login') return navigateTo('/login')
})
```

```vue
<!-- pages/admin.vue -->
<script setup lang="ts">
definePageMeta({ middleware: 'auth', layout: 'admin' })
</script>
```

詳細 Nuxt 路由 / SSR / server route → `nuxt` skill。

---

## 何時用 Vue Router

只要有 > 1 個「頁面級」畫面、需要前進後退 / 連結分享 / SEO — 就用 Vue Router，不要拿 `v-if` 切畫面。

## 延伸閱讀

- Vue Router 4：https://router.vuejs.org
- Navigation Guards：https://router.vuejs.org/guide/advanced/navigation-guards.html
- Composition API：https://router.vuejs.org/guide/advanced/composition-api.html
