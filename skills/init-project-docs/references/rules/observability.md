---
# init-project-docs：將下方 paths 換成 Phase 0 偵測到的真實目錄 glob，並刪除本註解行。
# Host 路由：Claude → 保留 `paths:`；Copilot → 鍵名改 `applyTo:`；Codex 無 path-scoping → 本檔內容併入 AGENTS.md 分節。
paths:
  - "{偵測到的日誌/中介層檔案 — 例：src/logger.*、src/middleware/**、Program.cs、Startup.cs}"
---

# Observability 規則

## Tracing / Metrics / Logs 三位一體

上線前必須確認三者皆接入：
- **Metrics**：RED（Rate / Error / Duration）per endpoint
- **Logs**：結構化（JSON）、含 correlation ID
- **Traces**：distributed trace 含跨服務 span

## OpenTelemetry 配置

- **.NET Core**：`OpenTelemetry.Extensions.Hosting` + `Serilog.Sinks.OpenTelemetry`
- **Node.js**：`@opentelemetry/sdk-node` + `@opentelemetry/auto-instrumentations-node`
- Exporter endpoint 由 env var 控制（`OTEL_EXPORTER_OTLP_ENDPOINT`）
- Service name 統一用 `OTEL_SERVICE_NAME` env var

## Correlation ID

- **HTTP header**：`X-Correlation-ID`（incoming 有則沿用，無則產生 UUID v4）
- **Log 欄位**：統一 `correlationId`（camelCase）
- **跨服務呼叫**：HTTP client middleware 自動注入 header
- **Background job**：從 trigger event 繼承或新生一個

## Logging 等級

| Level | 用途 |
|-------|------|
| `Trace` | 詳細流程追蹤（dev 環境） |
| `Debug` | 開發除錯（staging 可開） |
| `Information` | 正常業務事件（訂單建立、登入成功） |
| `Warning` | 可恢復異常（retry 成功、fallback 觸發） |
| `Error` | 業務 / 系統錯誤（需人介入） |
| `Critical` | 系統失效（立即告警） |

- Production 預設 `Information`，啟動時可動態調整
- **禁 log secrets / tokens / 完整信用卡號**；credit card 只留最後 4 碼
- 結構化欄位用 camelCase；`userId`、`orderId`、`traceId`

## Health Check

- **`/health`** — liveness：服務還活著（不檢查外部依賴）
- **`/health/ready`** — readiness：DB / cache / 外部服務皆可用
- Kubernetes probe 配置：`livenessProbe` → `/health`，`readinessProbe` → `/health/ready`
- Health endpoint 必須快（< 100 ms），不做深度檢查

## Metrics 命名

- RED：`http_requests_total`、`http_request_duration_seconds`、`http_request_errors_total`
- 標籤（tag / label）：`method`、`route`、`status_code`、`service`
- **禁高 cardinality 標籤**：`user_id`、`request_id` 不當 metric label（可當 log / trace 欄位）

## 告警策略

- Error rate > 1% / 5min → Warning
- Error rate > 5% / 5min → Critical（page on-call）
- P99 latency 超過 SLO → Warning
- Health check 連續失敗 3 次 → Critical

## Dashboard

- Grafana / Datadog dashboard 按 service 建立
- 預設顯示：RED、上游 service 依賴、DB 連線池、queue depth
- 儀表板隨 repo 版控（`dashboards/*.json`）
