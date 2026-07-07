# docs 文件品質對照範例

**判斷標準**：「若開發者不知道這件事，是否會影響其他模組的開發或整合？」符合此條件才需明確記錄。

---

## `<instruction-file>`（固定段落骨架）

`<instruction-file>` 是 target host 每個 session 會載入的根文件：Claude Code → `CLAUDE.md`，Codex CLI → `AGENTS.md`，GitHub Copilot CLI → `.github/copilot-instructions.md`（若同時產 `AGENTS.md`，Copilot 檔可作為 thin adapter）。**段落順序固定**以維持可預期性，並**必含一行計畫流程提示**，確保每次協作都知道計畫歸檔慣例。

```markdown
# <專案名稱>

## 專案概述
<一句話定位 + 技術棧摘要>

## 常用指令
| 指令 | 說明 |
|------|------|
| `<run 指令>` | 啟動 |
| `<test 指令>` | 測試 |

## 關鍵規則
- <依專案特性列 3–5 條>
- 功能開發於 `docs/plans/` 記錄計畫；完成後移至 `docs/plans/archive/`

## 文件索引
- `docs/README.md` — 快速開始
- `docs/ARCHITECTURE.md` — 架構、路由、schema
- `docs/DEVELOPMENT.md` — 開發規範、計畫歸檔流程
- `docs/FEATURES.md` — 功能行為與狀態
- `docs/TESTING.md` — 測試規範
- `docs/CHANGELOG.md` — 更新日誌
```

**為何固定**：根文件結構漂移會讓每個專案的 instruction file 長相不一、難維護；固定骨架使段落可預期。「計畫流程提示行」是 SDD 的入口——少了它，context 壓縮後 AI 不會知道 `docs/plans/` 慣例。

---

## ARCHITECTURE.md

### 不足（骨架式）

```markdown
## 架構

專案採用分層架構：
- Controllers 層處理 HTTP
- Services 層處理業務邏輯
- Repositories 層處理資料存取

使用 JWT 認證。
```

**問題**：任何 .NET 專案都能套這段；開發者無法知道本專案的實際 middleware 行為、JWT 參數、資料庫 schema。

### 充足

```markdown
## 啟動流程（Program.cs）

1. `WebApplication.CreateBuilder` 載入 `appsettings.{Environment}.json`
2. DI 註冊順序：`AddDbContext` → `AddSingleton<ICacheService>` → `AddScoped<IOrderService>`
3. Middleware pipeline（**順序敏感**）：
   `UseExceptionHandler` → `UseSerilogRequestLogging` → `UseCorrelationId` → `UseAuthentication` → `UseAuthorization` → `MapControllers`
4. `app.Run()` 前呼叫 `await db.Database.MigrateAsync()` 自動套 migration

## API 路由總覽

| 路由前綴 | 檔案 | 認證 | 說明 |
|---------|------|------|------|
| `/v1/auth` | `AuthController.cs` | 公開 | 登入、refresh token、登出 |
| `/v1/users` | `UsersController.cs` | JWT | 使用者 CRUD；admin role 限定 DELETE |
| `/v1/orders` | `OrdersController.cs` | JWT | 訂單建立 / 查詢；僅回傳本人訂單（除 admin） |

## 統一回應格式

成功：`{ "data": T, "message": "string?" }`
失敗：`{ "error": "string", "code": "BUSINESS_ERROR_CODE", "details": any? }`

錯誤碼定義於 `src/Errors/ErrorCodes.cs`；前端用 `code` 做 i18n key，不依賴 `error` 文字。

## 認證機制

- JWT 放 httpOnly cookie（`auth_token`）；有效期 15 分鐘
- Refresh token 放 httpOnly cookie（`refresh_token`）；有效期 7 天
- `AuthMiddleware`（`src/Middleware/AuthMiddleware.cs`）讀 cookie → 驗 signature → 注入 `HttpContext.User`
- `[Authorize]` 屬性走標準 ASP.NET Core pipeline；自訂屬性 `[RequireRole("admin")]` 於 `src/Attributes/`

## 資料庫 Schema（核心表）

### `users`
| 欄位 | 型別 | 約束 | 說明 |
|------|------|------|------|
| `id` | `uuid` | PK | |
| `email` | `varchar(255)` | UNIQUE, NOT NULL | |
| `password_hash` | `varchar(255)` | NOT NULL | Argon2id |
| `role` | `varchar(20)` | NOT NULL DEFAULT 'user' | `user` / `admin` |
| `created_at` | `timestamptz` | NOT NULL | |

### `orders`
（完整欄位表）

## 第三方整合

### Stripe 金流
- Webhook endpoint：`/webhooks/stripe`（公開，但驗 signature）
- 事件處理：`payment_intent.succeeded` → 訂單狀態改 `paid` + 發 email
- 重試機制：Stripe 自動 retry 3 次；處理必須 idempotent（用 `event.id` 去重）
```

**為何充足**：開發者讀完能直接動手，不需猜測中間件順序、schema 細節、webhook 處理流程。

---

## FEATURES.md

### 不足

```markdown
## 訂單功能
- 建立訂單
- 查詢訂單
- 取消訂單
```

**問題**：端點名稱開發者自己看 controller 也能找到；這份文件沒增加任何資訊。

### 充足

```markdown
## 訂單建立（POST /v1/orders）

**請求 body**
| 欄位 | 型別 | 必填 | 說明 |
|------|------|------|------|
| `items` | `Array<{productId, quantity}>` | 是 | 至少一筆 |
| `shipping_address_id` | `uuid` | 是 | 必須屬於當前 user |
| `coupon_code` | `string` | 否 | 折扣碼 |

**業務邏輯**
1. 驗證 items 內 product 全部存在且 `is_active=true`
2. 開 transaction：
   a. 檢查 inventory（`SELECT ... FOR UPDATE`）
   b. 扣庫存（失敗則 rollback，回 `INVENTORY_INSUFFICIENT`）
   c. 計算金額（含折扣、稅、運費）
   d. 建立 `orders` + `order_items` 紀錄
   e. 扣除 coupon 使用次數（如有）
3. 呼叫 Stripe `CreatePaymentIntent`（失敗不影響 order 建立，訂單狀態為 `pending_payment`）
4. 回傳 `{ orderId, clientSecret }`

**錯誤情境**
- `400 INVALID_SHIPPING_ADDRESS` — address_id 不屬於 user
- `409 INVENTORY_INSUFFICIENT` — 任一 product 庫存不足
- `409 COUPON_EXHAUSTED` — coupon 已達使用上限
- `502 PAYMENT_GATEWAY_ERROR` — Stripe 呼叫失敗（訂單已建，狀態 `pending_payment`，需手動重試）
```

**為何充足**：前後端開發者各自能直接實作，不需 review 程式碼或問人。

---

## DEVELOPMENT.md

### 不足

```markdown
## 開發規範
- 遵循團隊命名慣例
- 程式碼要寫註解
- 新功能要寫測試
```

**問題**：沒有具體對照，開發者無從得知本專案的實際慣例；任何專案都能套這段。

### 充足

```markdown
## 命名規則
| 元素 | 慣例 | 範例 |
|------|------|------|
| Controller | PascalCase + `Controller` 字尾 | `OrdersController` |
| DTO | PascalCase + `Request`/`Response` 字尾 | `CreateOrderRequest` |
| DB 欄位 | snake_case | `created_at` |
| 環境變數 | SCREAMING_SNAKE_CASE | `STRIPE_SECRET_KEY` |

## 新增一個 API endpoint 的步驟
1. 於 `src/Controllers/` 建 controller，繼承 `ApiControllerBase`
2. DTO 放 `src/Contracts/`，validator 用 FluentValidation 寫在 `src/Validators/`
3. 業務邏輯放 service（`src/Services/`），於 `Program.cs` 以 `AddScoped` 註冊
4. 更新 `docs/FEATURES.md` 與 `docs/ARCHITECTURE.md` 的路由總覽表

## 環境變數
| 變數 | 用途 | 必要 | 預設 |
|------|------|------|------|
| `DATABASE_URL` | PostgreSQL 連線字串 | 是 | — |
| `STRIPE_SECRET_KEY` | Stripe API 金鑰 | 是 | — |
| `LOG_LEVEL` | 日誌等級 | 否 | `Information` |
```

**為何充足**：開發者能照步驟新增功能、知道每個檔案歸屬、缺哪個環境變數會啟動失敗。

### 計畫格式（DEVELOPMENT.md 必含）

DEVELOPMENT.md 須包含「計畫歸檔流程」，規範功能開發計畫的生命週期：

1. **檔名慣例**：`docs/plans/YYYY-MM-DD-<feature-name>.md`（`YYYY-MM-DD` 為計畫**建立日**，建檔時即固定，不隨歸檔變動）
2. **文件結構**：`User Story → Spec → Tasks` 三段
3. **完成後**：在檔頭狀態行填入完成日，計畫檔移至 `docs/plans/archive/`（**檔名不變**）
4. **同步更新**：`docs/FEATURES.md`（功能狀態）與 `docs/CHANGELOG.md`

計畫檔最小骨架：

```markdown
# <feature-name>

> 狀態：進行中 ｜ 建立日：YYYY-MM-DD ｜ 完成日：—

## User Story
作為 <角色>，我想要 <能力>，以便 <價值>。

## Spec
功能行為、輸入/輸出、邊界條件、錯誤情境；列出可驗證的驗收條件。

## Tasks
- [ ] 任務一
- [ ] 任務二
```

歸檔時把狀態行更新為 `狀態：已完成 ｜ 建立日：… ｜ 完成日：<歸檔當天日期>`。歸檔日記在檔頭，不寫進檔名 —— 檔名前綴永遠是建立日，確保進行中與已歸檔計畫命名格式一致。

**為何需要**：計畫檔讓功能在動工前先寫清 User Story 與 Spec，完成後歸檔留下決策軌跡；檔名固定建立日、檔頭另記完成日，兩個時間點都可追溯；FEATURES.md / CHANGELOG.md 同步更新確保狀態不漂移。

---

## TESTING.md

### 不足

```markdown
## 測試
- 使用 xUnit
- 執行 `dotnet test`
- 盡量提高覆蓋率
```

**問題**：框架名稱看 csproj 就知道；沒說測試怎麼分層、有何前置依賴、踩過什麼坑。

### 充足

```markdown
## 測試結構
| 專案 | 類型 | 說明 |
|------|------|------|
| `Tests.Unit` | 單元 | 純邏輯、無 I/O，可平行 |
| `Tests.Integration` | 整合 | 用 Testcontainers 起真實 PostgreSQL |

## 執行
- 全部：`dotnet test`
- 僅單元（快）：`dotnet test Tests.Unit`
- 整合測試需 Docker daemon 運行；CI 於 `ci.yml` 的 `services` 區塊提供

## 輔助函式
- `TestDataFactory`（`Tests.Common/`）— 用 Bogus 產生實體假資料
- `IntegrationTestBase` — 每個 test class 起獨立 schema，結束後 drop

## 常見陷阱
- 整合測試共用 container，**不可**假設資料表為空 → 每個測試自建唯一資料
- `DateTime` 斷言用 `BeCloseTo`，避免時區與精度誤差
```

**為何充足**：開發者知道測試如何分層、跑哪個指令、整合測試的前置條件與已知雷區。

---

## README.md

### 不足

````markdown
# MyProject

一個訂單管理系統。

## 安裝
`npm install`

## 執行
`npm start`
````

**問題**：缺技術棧、缺完整可 copy-paste 的啟動步驟、缺文件索引；新人仍需問人才能跑起來。

### 充足

````markdown
# MyProject

訂單管理 API — .NET 8 + PostgreSQL + Stripe 金流。

## 技術棧
- .NET 8 / ASP.NET Core Web API
- PostgreSQL 16（EF Core）
- xUnit + Testcontainers

## 快速開始
```bash
cp .env.example .env          # 填入 DATABASE_URL、STRIPE_SECRET_KEY
docker compose up -d db       # 起本機資料庫
dotnet ef database update     # 套用 migration
dotnet run --project src/Api  # http://localhost:5080
```

## 常用指令
| 指令 | 說明 |
|------|------|
| `dotnet run --project src/Api` | 啟動 API |
| `dotnet test` | 跑全部測試 |
| `dotnet ef migrations add <Name>` | 新增 migration |

## 文件索引
| 文件 | 內容 |
|------|------|
| `docs/ARCHITECTURE.md` | 架構、路由、schema |
| `docs/DEVELOPMENT.md` | 開發規範、新增功能步驟 |
| `docs/FEATURES.md` | 功能行為與狀態 |
| `docs/TESTING.md` | 測試規範 |
````

**為何充足**：新人能 copy-paste 一次跑起來，並知道後續細節該往哪份文件查。

---

## 判斷準則摘要

| 應該寫 | 不必寫 |
|--------|--------|
| Middleware pipeline 順序 | 「使用 JWT 認證」 |
| Schema 欄位約束 | 「使用 PostgreSQL」 |
| Business logic 的 transaction 邊界 | 「採用 DDD」 |
| 錯誤碼與 HTTP status 對應 | 「有錯誤處理」 |
| 第三方整合的 retry / idempotency 策略 | 「串接 Stripe」 |
| 非標準機制（雙模式認證、多租戶切換） | 通用 MVC 概念 |

**原則**：內容愈「能取代與人對話」，價值愈高。
