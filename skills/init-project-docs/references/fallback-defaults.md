# 內建預設（fallback defaults）

當 Phase 0 無法取得執行 host 的全域指令檔（檔案不存在、解析失敗、格式與預期差異過大）時，載入此檔作為預設值，並明確告知使用者「未偵測到全域偏好，套用內建預設，可於 Phase 1 調整」。

各 host 的全域指令檔位置（依 Phase 0.5 偵測到的 host 取對應檔）：

| Host | 全域指令檔 |
|------|-----------|
| Claude Code | `~/.claude/CLAUDE.md` |
| Codex CLI | `~/.codex/AGENTS.md` |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md` |

所有選項皆為「合理的通用預設」，以主流開源實踐為基準；非個人偏好。

---

## Backend — .NET

| 項目 | 預設 | 備註 |
|------|------|------|
| API 風格 | Controller-based Web API | Minimal API 僅限 prototype |
| Host builder | `WebApplication.CreateBuilder`（API）/ `Host.CreateApplicationBuilder`（Worker） | |
| ORM | EF Core | 既有專案沿用原 ORM |
| 資料庫 | PostgreSQL | |
| Validation | FluentValidation | |
| Logging | Serilog + 結構化日誌 | |
| Error handling | Result pattern（業務失敗）+ typed exception（系統） | |
| API error format | `{ error: string, code: string, details?: any }` | |

## Backend — Node.js

| 項目 | 預設 |
|------|------|
| 框架 | Express 或 Fastify |
| ORM | Prisma |
| 驗證 | Zod |
| Logging | pino（結構化） |

## Backend — Python

| 項目 | 預設 |
|------|------|
| 框架 | FastAPI |
| ORM | SQLAlchemy 2.x |
| 驗證 | Pydantic v2 |
| Logging | `logging` + `structlog` |

---

## Frontend (SPA)

| 項目 | 預設 |
|------|------|
| Bundler + 框架 | Vite + React 18 或 Vue 3 |
| Language | TypeScript（strict + `noUncheckedIndexedAccess` + `verbatimModuleSyntax`） |
| Styling | Tailwind CSS |
| Component lib | React → shadcn/ui；Vue → Naive UI |
| State | `useState` + Context / `ref` + `provide/inject`（共用超過 3 處才引入 Zustand / Pinia） |
| Data | TanStack Query + Axios（統一 interceptor） |
| Form | React Hook Form / VeeValidate + Zod |
| Routing | React Router v7 / Vue Router |
| Logging | pino |

---

## Security

| 項目 | 預設 |
|------|------|
| Web API Auth | JWT 放 httpOnly cookie |
| Secrets | env var 或 secret manager；提供 `.env.example` |
| WinForms / Console local | DPAPI / `ProtectedData` |
| Frontend storage | localStorage / sessionStorage 禁放 tokens |
| 密碼 hash | Argon2id / bcrypt |

---

## Testing

| 項目 | 預設 |
|------|------|
| .NET | xUnit |
| Frontend | Vitest + React Testing Library / `@vue/test-utils` |
| Python | pytest |
| E2E | Playwright |
| 命名 | `MethodName_Scenario_ExpectedResult`（.NET）；`describe/it` 自然語言（frontend / python） |
| Integration 覆蓋 | auth / payment / 持久化 / 外部整合 |

---

## Observability

| 項目 | 預設 |
|------|------|
| Tracing | OpenTelemetry |
| Health check | `/health`（liveness）+ `/health/ready`（readiness） |
| Correlation ID | HTTP header `X-Correlation-ID`，log 欄位 `correlationId` |
| 上線前 | RED metrics + logs + traces 三者皆接入 |

---

## Git

| 項目 | 預設 |
|------|------|
| Commit 規範 | Conventional Commits，zh-TW title（`feat(api): ...`） |
| Branch | `feat/`, `fix/`, `chore/`, `refactor/` |
| PR merge | 預設 squash |
| Tag | `v{major}.{minor}.{patch}` SemVer |

---

## CI / CD

| 項目 | 預設 |
|------|------|
| Pipeline | lint → test → build →（選）security scan |
| Lockfile | 必 commit |
| Dependency update | Renovate / Dependabot；patch 自動合併，minor 週期評估，major 開 PR |
| Release | 產 SBOM（CycloneDX） |

---

## 使用說明

1. 於 Phase 0 發現 host 全域指令檔缺失時，agent 應讀本檔並於對話中告知（將 `<host 全域指令檔>` 換成上表對應路徑）：
   > 「未偵測到全域 `<host 全域指令檔>`，本次套用內建預設（後端：.NET Controller-based + EF Core + PostgreSQL；前端：Vite + TS；測試：xUnit / Vitest；認證：JWT httpOnly cookie）。如需調整，請於接下來的 Phase 1 告知。」

2. 本檔的項目名稱與全域指令檔區段對齊，之後若全域偏好恢復，可一鍵對照替換。

3. 本檔僅作 fallback；若全域偏好存在但某項未定義，優先填入此處預設並於輸出中標註「來源：fallback-default」。
