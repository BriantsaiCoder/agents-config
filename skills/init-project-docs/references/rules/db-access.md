---
# init-project-docs：將下方 paths 換成 Phase 0 偵測到的真實目錄 glob，並刪除本註解行。
# Host 路由：Claude → 保留 `paths:`；Copilot → 鍵名改 `applyTo:`；Codex 無 path-scoping → 本檔內容併入 AGENTS.md 分節。
paths:
  - "{偵測到的資料存取目錄 — 例：src/database.*、src/models/**、prisma/**、Infrastructure/**}"
---

# 資料庫規則

## 欄位命名

- Primary key：`id`（統一），型別 `uuid` 或 `bigint`；避免用業務欄位當 PK
- Foreign key：`{resource}_id`（例：`user_id`、`order_id`）
- 時間欄位：`created_at`、`updated_at`、`deleted_at`（軟刪除），型別 `timestamptz`（PostgreSQL）
- 布林：`is_*` 或 `has_*` 前綴
- 金額：`decimal(18, 4)`，不用 `float` / `double`

## 型別約束

- 所有欄位預設 `NOT NULL`，明確需要 nullable 才 allow NULL
- String 欄位明確長度（VARCHAR(N)）；不用無上限 TEXT 除非必要
- JSON 欄位優先 `jsonb`（PostgreSQL） / `JSON` 實體欄位（MySQL），不存 `TEXT`
- 金錢欄位加 `CHECK (amount >= 0)` 約束

## Migration / Schema 變更

- Migration 檔案命名：`YYYYMMDDHHMMSS_<description>.sql`
- 一個 migration 做一件事（加欄位、加表、加 index 分開）
- 大表加欄位必須 nullable 或有 default；production migration 前先在 staging 跑過
- 加 index 用 `CONCURRENTLY`（PostgreSQL）避免鎖表

## 查詢原則

- 避免 `SELECT *`；明確列出需要的欄位
- Foreign key 必須有 index
- 分頁用 cursor-based（`WHERE id > :lastId`），避免大表 OFFSET
- N+1 檢測：trace EF Core `Include` / Prisma `include` / TypeORM `relations` 使用

## 專案特定 ORM 慣例

- {依偵測到的 ORM 填入，例：EF Core → `AsNoTracking()` for read-only queries；Dapper → 參數化查詢，不字串拼接}
