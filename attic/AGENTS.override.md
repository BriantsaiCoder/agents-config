# Codex Global Overrides

## Communication

- 預設使用 zh-TW 回覆，technical terms 保留 English；除非使用者明確要求其他語言。

## Mandatory Closeout Ledger

After every implementation, PR creation, merge, or squash merge, the final response must include a visible `Closeout Ledger`. Do not only say the work is done.

Required rows:

- Self-simplification: PASS / FAIL / SKIPPED, with evidence.
- Diff self-review: PASS / FAIL / SKIPPED, with evidence.
- Relevant verification: exact commands or tool checks, plus result summary.
- Review gate: reviewer type, agent id or unavailable reason, and final finding summary.
- PR / CI / review status when applicable.
- Residual risks.

If this ledger is omitted, the closeout report is incomplete.

## Mandatory PR Copilot Review Monitoring

For every GitHub PR, request Copilot review when the repository supports it. Prefer reviewer slug `copilot-pull-request-reviewer`; if unavailable, use the repository-supported equivalent and record the fallback.

After creating or updating a PR, keep monitoring CI and review state until checks reach a terminal state and automated review either appears, is clearly unavailable, or reaches a reasonable timeout. If the PR remains open, create or update a heartbeat/automation to keep monitoring until the PR is closed or merged. If CI fails or Copilot/review comments are technically valid and actionable, fix them automatically, verify, push, and monitor the new result again until PR closure.

<!-- agents-tier0:begin FP:OVERRIDE-T0-2026Q3（止血 stamp；終局遷移 Step 8 隨本檔退役）-->
## Hard Rules（tier0 安全底線）
- [T0-1] MUST NOT 假設未驗證的 file path / API / config key。
- [T0-2] MUST NOT 無 evidence 宣稱 task done（evidence = test/build/lint 輸出或探針結果）。
- [T0-3] MUST NOT force-push main/master；force push 只用 --force-with-lease 於非保護分支。
- [T0-4] MUST NOT 把 token/secret 寫入 frontend localStorage/sessionStorage；log/console 不印憑證，設定輸出遮罩。
- [T0-5] 模糊時 MUST 停下發問（攤開假設 X、影響範圍 Y），不靜默推進。
- [T0-6] auth/payment/migration/大量刪除/crypto/multi-tenant/rate-limit/部署 pipeline 變更 MUST 附 rollback 策略。
- [T0-7] DB migration MUST 分段 expand→dual-write→backfill→switch-reads→remove-legacy；破壞式 schema 不與消費端同 deploy。
- [T0-8] 非 trivial（3+ 步/多檔/架構性）MUST 先出計畫並取得用戶確認才改檔（任何 auto 模式不豁免）。
- [T0-9] merge 前 MUST 綠 CI + 處理 bot review（bot review 異步 2–3 分鐘產出，開 PR 當下為空是延遲不是無）。
<!-- agents-tier0:end -->

<!-- agents-routing:begin | generated-from: ~/.agents/core/routing.md | last-verified: 2026-07-07 -->
<!-- FP:ROUTING-2026Q3 -->

# 開發任務路由（薄層；workflow 正本在 dev-workflow skill）

- 任何開發任務：先讀 ~/.agents/skills/dev-workflow/SKILL.md 並照其 S0 決策表路由。描述含錯誤行為 / 測試失敗 / regression 的走 SKILL.md 的 BUGFIX 鏈；單檔 / ≤1 天小需求走 skill sdd。
- 逐名點名 skill（Codex 端 description 被截斷至 2–6 字元，路由靠點名不靠 description）：dev-workflow、sdd、deps-check、mp-grill-with-docs、mp-diagnose、bug-fix-settlement、frontend-release-verification、backend-release-verification、dependency-security-scan、design-doc-mermaid。

## 最高風險攔截（常駐，防新鮮 skill prose 搶贏路由，尤其 superpowers 終態鏈）

- [R-1] 收尾類 skill（如 finishing-a-development-branch）MUST NOT 在 S4/S5 全綠前 invoke。觸發：任務仍有 FAIL 或未跑的 verify / review gate。驗證：S4 與 S5 四態全 PASS 才放行。例外：無。
- [R-2] fix 之前 MUST 先有 failing regression test（紅→綠）；無可測 seam 須明確標記例外並附替代驗證。觸發：修 bug 的變更無先行紅測。驗證：紅燈輸出存在於證據。例外：無。
- [R-3] S2 ⏸ plan gate 在任何 auto / autopilot 模式下 MUST NOT 豁免。觸發：非 plan 模式且將改檔。驗證：改檔前有計畫產物＋引用用戶確認原句。例外：無。

<!-- agents-routing:end -->
