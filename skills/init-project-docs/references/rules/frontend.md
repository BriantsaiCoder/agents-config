---
# init-project-docs：將下方 paths 換成 Phase 0 偵測到的真實目錄 glob，並刪除本註解行。
# Host 路由：Claude → 保留 `paths:`；Copilot → 鍵名改 `applyTo:`；Codex 無 path-scoping → 本檔內容併入 AGENTS.md 分節。
paths:
  - "{偵測到的前端目錄 — 例：views/**、src/components/**、src/pages/**、templates/**}"
---

# 前端規則

## A11y（必須）

- **React**：啟用 `eslint-plugin-jsx-a11y`（recommended 設定）
- **Vue**：啟用 `eslint-plugin-vuejs-accessibility`
- 互動元素（button、link）必須可鍵盤操作；`onClick` 於 div/span 上屬 anti-pattern
- 圖片 `alt`、form label、ARIA role 不可省略

## 錯誤處理

- 每個 route / page 外層包 error boundary；error boundary 回報錯誤至 logging
- HTTP error 由 Axios interceptor 統一處理（網路錯誤、401、500）
- User 面向錯誤用 toast / inline message，不用 `alert()` / `window.confirm()`

## TypeScript

- `tsconfig.json` 啟用 `strict`、`noUncheckedIndexedAccess`、`verbatimModuleSyntax`
- 禁 `any`；需要時用 `unknown` + type guard
- Form / API schema 用 Zod，型別用 `z.infer<typeof schema>`，**不重複定義**

## State 管理

- 預設：`useState` + Context（React） / `ref` + `provide/inject`（Vue）
- **共用超過 3 處**才引入 Zustand / Pinia，不預設 Redux
- Server state 用 TanStack Query；**不用 Redux 存 API 資料**

## Data Fetching

- 統一 Axios instance（base URL、auth header、interceptor）
- TanStack Query 的 `staleTime` 必須顯式設定（預設 0 會每次 mount 重抓）
- Mutation 成功後 invalidate 相關 query，不手動 setData

## 樣式

- 優先用 Tailwind utility；重複 3+ 次以上抽 component
- **禁 inline styles** 除非動態計算值
- **禁 `!important`** 除非覆蓋第三方庫
- Design tokens（顏色、spacing）寫在 `tailwind.config.*`，不 hardcode 於 component

## 元件結構

- 單一檔案 < 250 行；超過則拆 sub-component
- Props 用 TS interface，必填與選填明確區分
- 避免 barrel exports（`index.ts` re-export）拖慢 bundle / tree-shaking

## 框架特定

- **React**：避免 class components；hooks 依賴陣列必須完整
- **Vue 3**：`<script setup>` + Composition API；禁 Options API 於新 component
