---
# init-project-docs：將下方 paths 換成 Phase 0 偵測到的真實目錄 glob，並刪除本註解行。
# Host 路由：Claude → 保留 `paths:`；Copilot → 鍵名改 `applyTo:`；Codex 無 path-scoping → 本檔內容併入 AGENTS.md 分節。
paths:
  - "{偵測到的測試目錄 — 例：tests/**、__tests__/**、*.Tests/**、spec/**}"
---

# 測試規則

## 框架選擇

- **.NET**：xUnit（新專案統一）；現有 NUnit/MSTest 專案沿用不強制遷移
- **Frontend**：Vitest + React Testing Library / `@vue/test-utils`
- **Node.js**：Vitest（優先）或 Jest（既有專案）
- **E2E**：Playwright

## 命名慣例

- **.NET**：`MethodName_Scenario_ExpectedResult`
  - 範例：`CreateOrder_WhenInventoryInsufficient_ReturnsError`
- **Frontend / Node.js**：`describe` 為被測對象，`it` 為自然語言
  - 範例：`describe('useAuth')` → `it('returns user when token is valid')`

## 測試結構（AAA）

```
// Arrange — 準備測試資料與 mock
// Act — 呼叫被測方法
// Assert — 驗證結果
```

不要在單一測試混多個行為；一個測試驗一件事。

## 覆蓋範圍

- Integration tests 必須覆蓋：auth 流程、payment 流程、持久化層（DB/cache）、外部整合（第三方 API）
- Unit tests 覆蓋：業務邏輯、純函式、edge cases
- **WinForms 專案**：邏輯抽到 ViewModel / Presenter / Service 測試，**不直接測 Form**

## Fixture / Mock 策略

- Integration tests 用真 DB（Testcontainers / Docker）；**不 mock DB**
- HTTP 外部呼叫：用 `WireMock.Net` / `msw` 攔截，不 mock SDK client
- 共用 fixture 放 `tests/fixtures/` 或 `tests/helpers/`

## 執行順序

- 測試**必須可獨立執行**，不依賴執行順序
- 共用資源（DB / file system）用 transaction rollback 或 per-test cleanup
- Flaky test 優先修，不用 retry 掩蓋

## 新增測試流程

1. 先寫失敗的測試（Red）
2. 最小實作讓測試通過（Green）
3. 重構但保持測試通過（Refactor）
4. Commit：`test(module): add test for xxx`
