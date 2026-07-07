---
# init-project-docs：將下方 paths 換成 Phase 0 偵測到的真實目錄 glob，並刪除本註解行。
# Host 路由：Claude → 保留 `paths:`；Copilot → 鍵名改 `applyTo:`；Codex 無 path-scoping → 本檔內容併入 AGENTS.md 分節。
paths:
  - "{偵測到的路由/API 目錄 — 例：src/routes/**、app/api/**、Controllers/**}"
---

# API 設計規則

## 回應格式

成功：`{ data: T, message?: string }`
失敗：`{ error: string, code: string, details?: any }`

- HTTP status code 與 `code` 欄位對應；`code` 為業務錯誤代碼（例：`USER_NOT_FOUND`、`INVALID_TOKEN`）
- `error` 為可面向 user 的訊息（i18n key 或人類可讀字串）
- `details` 僅用於開發環境的除錯資訊，production 環境必須移除或 sanitize

## 路由命名

- RESTful：資源用複數名詞（`/users`、`/orders`），避免動詞
- Nested resources 限一層：`/users/:id/orders` 可，`/users/:id/orders/:oid/items` 改為 `/orders/:oid/items`
- 版本放 path：`/v1/users`，不放 header（降低除錯複雜度）

## 驗證

- Request body / query 必須用 schema validation（FluentValidation / Zod / express-validator）
- 驗證失敗統一回 400 + 上述 error format
- 參數型別在 route handler 入口驗證，不假設 framework 已驗證

## 文件註解

- Controller / route handler 上方必須有 summary（.NET：XML doc、TS：JSDoc）
- 標註可能的錯誤回應（status code + code 對應表）
- Public endpoint 須明確註記 `@public`；預設視為需認證
